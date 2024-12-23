use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

#[starknet::contract]
mod StakingContract {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        token: ContractAddress,
        stakes: Map::<ContractAddress, u256>,
        total_staked: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Staked: Staked,
        Withdrawn: Withdrawn,
    }

    #[derive(Drop, starknet::Event)]
    struct Staked {
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawn {
        user: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.token.write(token_address);
        self.total_staked.write(0);
    }

    #[external(v0)]
    fn stake(ref self: ContractState, amount: u256) {
        assert(amount > 0, 'Amount must be greater than 0');
        let caller = get_caller_address();
        
        // Transfer tokens from user to contract
        let token = IERC20Dispatcher { contract_address: self.token.read() };
        token.transfer_from(caller, get_contract_address(), amount);

        // Update state
        let current_stake = self.stakes.read(caller);
        self.stakes.write(caller, current_stake + amount);
        self.total_staked.write(self.total_staked.read() + amount);

        // Emit event
        self.emit(Event::Staked(Staked { user: caller, amount }));
    }

    #[external(v0)]
    fn withdraw(ref self: ContractState, amount: u256) {
        let caller = get_caller_address();
        let current_stake = self.stakes.read(caller);
        
        assert(amount > 0, 'Amount must be greater than 0');
        assert(current_stake >= amount, 'Insufficient stake');

        // Update state
        self.stakes.write(caller, current_stake - amount);
        self.total_staked.write(self.total_staked.read() - amount);

        // Transfer tokens back to user
        let token = IERC20Dispatcher { contract_address: self.token.read() };
        token.transfer(caller, amount);

        // Emit event
        self.emit(Event::Withdrawn(Withdrawn { user: caller, amount }));
    }

    #[external(v0)]
    fn get_stake(self: @ContractState, user: ContractAddress) -> u256 {
        self.stakes.read(user)
    }

    #[external(v0)]
    fn get_total_staked(self: @ContractState) -> u256 {
        self.total_staked.read()
    }
}

   