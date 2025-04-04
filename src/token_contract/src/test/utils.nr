use crate::Token;
use aztec::{
    note::{constants::MAX_NOTES_PER_PAGE, note_getter::view_notes},
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::{AztecAddress, NoteHeader, NoteViewerOptions},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use std::test::OracleMock;
use uint_note::uint_note::UintNote;

pub unconstrained fn setup(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, recipient) = if with_account_contracts {
        let owner = env.create_account_contract(1);
        let recipient = env.create_account_contract(2);
        (owner, recipient)
    } else {
        let owner = env.create_account(1);
        let recipient = env.create_account(2);
        (owner, recipient)
    };

    let token_contract_address = deploy_token(&mut env, owner);

    (&mut env, token_contract_address, owner, recipient)
}

pub unconstrained fn deploy_token(env: &mut TestEnvironment, owner: AztecAddress) -> AztecAddress {
    // Start the test in the account contract address
    env.impersonate(owner);

    // Deploy token contract
    let initializer_call_interface = Token::interface().constructor(
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
    );
    let token_contract = env.deploy("./@token_contract", "Token").with_public_void_initializer(
        initializer_call_interface,
    );
    env.advance_block_by(1);

    token_contract.to_address()
}

pub unconstrained fn setup_and_mint_to_public(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, U128) {
    // Setup
    let (env, token_contract_address, owner, recipient) = setup(with_account_contracts);
    let mint_amount = U128::from_integer(10000);
    // Mint some tokens
    Token::at(token_contract_address).mint_to_public(owner, mint_amount).call(&mut env.public());

    (env, token_contract_address, owner, recipient, mint_amount)
}

pub unconstrained fn setup_and_mint_amount_to_private(
    with_account_contracts: bool,
    mint_amount: U128,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, U128) {
    // Setup the tokens and mint public balance
    let (env, token_contract_address, owner, recipient) = setup(with_account_contracts);

    // Mint some tokens
    mint_to_private(env, token_contract_address, owner, mint_amount);

    (env, token_contract_address, owner, recipient, mint_amount)
}

pub unconstrained fn setup_and_mint_to_private(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, U128) {
    let mint_amount = U128::from_integer(10000);
    setup_and_mint_amount_to_private(with_account_contracts, mint_amount)
}

pub unconstrained fn mint_to_private(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: U128,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    let from = recipient; // we are setting from to recipient because of TODO(#9887)
    Token::at(token_contract_address).mint_to_private(from, recipient, amount).call(
        &mut env.private(),
    );

    env.advance_block_by(1);
}

pub unconstrained fn transfer_in_private(
    env: &mut TestEnvironment,
    from: AztecAddress,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: U128,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    env.impersonate(from);
    Token::at(token_contract_address).transfer_private_to_private(from, recipient, amount, 0).call(
        &mut env.private(),
    );

    env.advance_block_by(1);
}

pub unconstrained fn check_public_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let balances_slot = Token::storage_layout().public_balances.slot;
    let address_slot = derive_storage_slot_in_map(balances_slot, address);
    let amount: U128 = storage_read(token_contract_address, address_slot, block_number);
    assert(amount == address_amount, "Public balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn get_public_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
) -> U128 {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let balances_slot = Token::storage_layout().public_balances.slot;
    let address_slot = derive_storage_slot_in_map(balances_slot, address);
    let amount: U128 = storage_read(token_contract_address, address_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);
    amount
}

pub unconstrained fn check_total_supply(
    token_contract_address: AztecAddress,
    expected_total_supply: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let total_supply_slot = Token::storage_layout().total_supply.slot;
    let total_supply: U128 = storage_read(token_contract_address, total_supply_slot, block_number);
    assert(total_supply == expected_total_supply, "Total supply is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn get_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
) -> U128 {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let amt = Token::balance_of_private(address);
    cheatcodes::set_contract_address(current_contract_address);
    amt
}

// This is used if we need to add a token note manually, in the case where the note is not emitted in logs.
pub unconstrained fn add_token_note(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    owner: AztecAddress,
    amount: U128,
    note_randomness: Field,
) {
    let balances_owner_slot =
        derive_storage_slot_in_map(Token::storage_layout().private_balances.slot, owner);

    env.add_note(
        &mut UintNote {
            value: amount,
            owner: owner,
            randomness: note_randomness,
            header: NoteHeader::empty(),
        },
        balances_owner_slot,
        token_contract_address,
    );
}

pub unconstrained fn get_private_balance_notes(
    account: AztecAddress,
    offset: u32,
) -> BoundedVec<UintNote, MAX_NOTES_PER_PAGE> {
    let mut options = NoteViewerOptions::new();
    let private_balances_slot = Token::storage_layout().private_balances.slot;
    let private_balance_slot = derive_storage_slot_in_map(private_balances_slot, account);
    let notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        view_notes(private_balance_slot, options.set_offset(offset));
    notes
}
