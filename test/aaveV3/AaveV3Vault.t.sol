pragma solidity ^0.8.4;

import 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';

import {ERC20} from 'solmate/tokens/ERC20.sol';
import {IPool} from '../../src/providers/aaveV3/external/IPool.sol';
import {IRewardsController} from '../../src/providers/aaveV3/external/IRewardsController.sol';

import {PoolMock} from './mocks/Pool.m.sol';
import {RewardsControllerMock} from './mocks/RewardsController.m.sol';
import {ERC20Mock} from '../mocks/ERC20.m.sol';

import {AaveV3Vault} from '../../src/providers/aaveV3/AaveV3Vault.sol';
import {AaveV3VaultFactory} from '../../src/providers/aaveV3/AaveV3VaultFactory.sol';

contract AaveV3VaultTest is Test {
    address public constant rewardRecipient = address(0x01);

    ERC20Mock public aave;
    ERC20Mock public aToken;
    AaveV3Vault public vault;
    ERC20Mock public underlying;
    PoolMock public lendingPool;
    AaveV3VaultFactory public factory;
    IRewardsController public rewardsController;

    function setUp() public {
        aave = new ERC20Mock();
        aToken = new ERC20Mock();
        underlying = new ERC20Mock();
        lendingPool = new PoolMock();
        rewardsController = new RewardsControllerMock(address(aave));
        factory = new AaveV3VaultFactory(
            lendingPool,
            rewardRecipient,
            rewardsController
        );

        lendingPool.setReserveAToken(address(underlying), address(aToken));

        vault = AaveV3Vault(address(factory.createERC4626(underlying)));
    }

    function testSingleDepositWithdraw(uint128 amount) public {
        vm.assume(amount > 0);
        uint256 aliceUnderlyingAmount = amount;

        address alice = address(0xABCD);

        underlying.mint(alice, aliceUnderlyingAmount);

        vm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(
            underlying.allowance(alice, address(vault)),
            aliceUnderlyingAmount
        );

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        vm.prank(alice);
        uint256 aliceShareAmount = vault.deposit(aliceUnderlyingAmount, alice);

        // Expect exchange rate to be 1:1 on initial deposit.
        assertEq(aliceUnderlyingAmount, aliceShareAmount);
        assertEq(
            vault.previewWithdraw(aliceShareAmount),
            aliceUnderlyingAmount
        );
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            underlying.balanceOf(alice),
            alicePreDepositBal - aliceUnderlyingAmount
        );

        vm.prank(alice);
        vault.withdraw(aliceUnderlyingAmount, alice, alice);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }

    function testSingleMintRedeem(uint128 amount) public {
        vm.assume(amount > 0);
        uint256 aliceShareAmount = amount;

        address alice = address(0xABCD);

        underlying.mint(alice, aliceShareAmount);

        vm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(aliceShareAmount, alice);

        // Expect exchange rate to be 1:1 on initial mint.
        assertEq(aliceShareAmount, aliceUnderlyingAmount);
        assertEq(
            vault.previewWithdraw(aliceShareAmount),
            aliceUnderlyingAmount
        );
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceUnderlyingAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            underlying.balanceOf(alice),
            alicePreDepositBal - aliceUnderlyingAmount
        );

        vm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }

    function testFailDepositWithNotEnoughApproval(
        uint128 amountA,
        uint128 amountB
    ) public {
        vm.assume(amountA < amountB);
        underlying.mint(address(this), amountA);
        underlying.approve(address(vault), amountA);
        assertEq(underlying.allowance(address(this), address(vault)), amountA);

        vault.deposit(amountB, address(this));
    }

    function testFailWithdrawWithNotEnoughUnderlyingAmount(
        uint128 amountA,
        uint128 amountB
    ) public {
        vm.assume(amountA < amountB);
        underlying.mint(address(this), amountA);
        underlying.approve(address(vault), amountA);

        vault.deposit(amountA, address(this));

        vault.withdraw(amountB, address(this), address(this));
    }

    function testFailRedeemWithNotEnoughShareAmount(
        uint128 amountA,
        uint128 amountB
    ) public {
        vm.assume(amountA < amountB);
        underlying.mint(address(this), amountA);
        underlying.approve(address(vault), amountA);

        vault.deposit(amountA, address(this));

        vault.redeem(amountB, address(this), address(this));
    }

    function testFailWithdrawWithNoUnderlyingAmount(uint128 amount) public {
        vm.assume(amount > 0);
        vault.withdraw(amount, address(this), address(this));
    }

    function testFailRedeemWithNoShareAmount(uint128 amount) public {
        vault.redeem(amount, address(this), address(this));
    }

    function testFailDepositWithNoApproval(uint128 amount) public {
        vm.assume(amount > 0);
        vault.deposit(amount, address(this));
    }

    function testFailMintWithNoApproval(uint128 amount) public {
        vm.assume(amount > 0);
        vault.mint(amount, address(this));
    }

    function testMintZero() public {
        vault.mint(0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testWithdrawZero() public {
        vault.withdraw(0, address(this), address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    // function testVaultInteractionsForSomeoneElse(
    //     uint64 amountA,
    //     uint64 amountB,
    //     uint64 yield
    // ) public {
    //     vm.assume(amountA > 1e18);
    //     vm.assume(amountB > 1e18);
    //     vm.assume(yield > 1e18);
    //     // init 2 users with a 1e18 balance
    //     address alice = address(0xABCD);
    //     address bob = address(0xDCBA);
    //     underlying.mint(alice, amountA);
    //     underlying.mint(bob, amountB);

    //     vm.prank(alice);
    //     underlying.approve(address(vault), amountA);

    //     vm.prank(bob);
    //     underlying.approve(address(vault), amountB);

    //     // alice deposits for bob
    //     vm.prank(alice);
    //     vault.deposit(amountA, bob);

    //     assertEq(vault.balanceOf(alice), 0);
    //     assertEq(vault.balanceOf(bob), amountA);
    //     assertEq(underlying.balanceOf(alice), 0);

    //     // bob mint for alice
    //     uint256 sharesBefore = vault.convertToShares(amountB);
    //     vm.prank(bob);
    //     vault.mint(sharesBefore, alice);
    //     assertEq(vault.balanceOf(alice), amountB);
    //     assertEq(vault.balanceOf(bob), amountA);
    //     assertEq(underlying.balanceOf(bob), 0);

    //     underlying.mint(address(lendingPool), yield);
    //     aToken.mint(address(vault), yield);

    //     // alice redeem for bob
    //     uint256 sharesAfter = vault.convertToShares(amountB);
    //     vm.prank(alice);
    //     vault.redeem(sharesAfter, bob, alice);
    //     assertEq(vault.balanceOf(alice), 0);
    //     assertEq(vault.balanceOf(bob), amountA);
    //     assertEq(underlying.balanceOf(bob), amountB);

    //     // bob withdraw for alice
    //     vm.prank(bob);
    //     vault.withdraw(amountA, alice, bob);
    //     assertEq(vault.balanceOf(alice), 0);
    //     assertEq(vault.balanceOf(bob), 0);
    //     assertEq(underlying.balanceOf(alice), amountA);
    // }

    function testClaimRewards() public {
        vault.claimRewards();

        assertEqDecimal(aave.balanceOf(rewardRecipient), 1e18, 18);
    }

    function testE2EIteractions() public {
        uint128 mutationUnderlyingAmount = 3000;

        address alice = address(0xABCD);
        address bob = address(0xDCBA);

        underlying.mint(alice, 4000);

        vm.prank(alice);
        underlying.approve(address(vault), 4000);

        assertEq(underlying.allowance(alice, address(vault)), 4000);

        underlying.mint(bob, 7001);

        vm.prank(bob);
        underlying.approve(address(vault), 7001);

        assertEq(underlying.allowance(bob, address(vault)), 7001);

        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(2000, alice);
        uint256 aliceShareAmount = vault.previewDeposit(aliceUnderlyingAmount);

        // Expect to have received the requested mint amount.
        assertEq(aliceShareAmount, 2000);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            vault.convertToShares(aliceUnderlyingAmount),
            vault.balanceOf(alice)
        );

        // Expect a 1:1 ratio before mutation.
        assertEq(aliceUnderlyingAmount, 2000);

        // Sanity check.
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);

        // 2. Bob deposits 4000 tokens (mints 4000 shares)
        vm.prank(bob);
        uint256 bobShareAmount = vault.deposit(4000, bob);
        uint256 bobUnderlyingAmount = vault.previewWithdraw(bobShareAmount);

        // Expect to have received the requested underlying amount.
        assertEq(bobUnderlyingAmount, 4000);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(bob)),
            bobUnderlyingAmount
        );
        assertEq(
            vault.convertToShares(bobUnderlyingAmount),
            vault.balanceOf(bob)
        );

        // Expect a 1:1 ratio before mutation.
        assertEq(bobShareAmount, bobUnderlyingAmount);

        // Sanity check.
        uint256 preMutationShareBal = aliceShareAmount + bobShareAmount;
        uint256 preMutationBal = aliceUnderlyingAmount + bobUnderlyingAmount;
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(vault.totalAssets(), preMutationBal);
        assertEq(vault.totalSupply(), 6000);
        assertEq(vault.totalAssets(), 6000);

        // 3. Vault mutates by +3000 tokens...                    |
        //    (simulated yield returned from strategy)...
        // The Vault now contains more tokens than deposited which causes the exchange rate to change.
        // Alice share is 33.33% of the Vault, Bob 66.66% of the Vault.
        // Alice's share count stays the same but the underlying amount changes from 2000 to 3000.
        // Bob's share count stays the same but the underlying amount changes from 4000 to 6000.
        underlying.mint(address(lendingPool), mutationUnderlyingAmount);
        aToken.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(
            vault.totalAssets(),
            preMutationBal + mutationUnderlyingAmount
        );
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount + (mutationUnderlyingAmount / 3) * 1
        );
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(bob)),
            bobUnderlyingAmount + (mutationUnderlyingAmount / 3) * 2
        );

        // 4. Alice deposits 2000 tokens (mints 1333 shares)
        vm.prank(alice);
        vault.deposit(2000, alice);

        assertEq(vault.totalSupply(), 7333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4999);
        assertEq(vault.balanceOf(bob), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);

        // 5. Bob mints 2000 shares (costs 3001 assets)
        // NOTE: Bob's assets spent got rounded up
        // NOTE: Alices's vault assets got rounded up
        vm.prank(bob);
        vault.mint(2000, bob);

        assertEq(vault.totalSupply(), 9333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 5000);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 9000);

        // Sanity checks:
        // Alice and bob should have spent all their tokens now
        assertEq(underlying.balanceOf(alice), 0);
        assertEq(underlying.balanceOf(bob), 0);
        // Assets in vault: 4k (alice) + 7k (bob) + 3k (yield) + 1 (round up)
        assertEq(vault.totalAssets(), 14001);

        // 6. Vault mutates by +3000 tokens
        // NOTE: Vault holds 17001 tokens, but sum of assetsOf() is 17000.
        underlying.mint(address(lendingPool), mutationUnderlyingAmount);
        aToken.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalAssets(), 17001);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 6071);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);

        // 7. Alice redeem 1333 shares (2428 assets)
        vm.prank(alice);
        vault.redeem(1333, alice, alice);

        assertEq(underlying.balanceOf(alice), 2428);
        assertEq(vault.totalSupply(), 8000);
        assertEq(vault.totalAssets(), 14573);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);

        // 8. Bob withdraws 2929 assets (1608 shares)
        vm.prank(bob);
        vault.withdraw(2929, bob, bob);

        assertEq(underlying.balanceOf(bob), 2929);
        assertEq(vault.totalSupply(), 6392);
        assertEq(vault.totalAssets(), 11644);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8000);

        // 9. Alice withdraws 3643 assets (2000 shares)
        // NOTE: Bob's assets have been rounded back up
        vm.prank(alice);
        vault.withdraw(3643, alice, alice);

        assertEq(underlying.balanceOf(alice), 6071);
        assertEq(vault.totalSupply(), 4392);
        assertEq(vault.totalAssets(), 8001);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8001);

        // 10. Bob redeem 4392 shares (8001 tokens)
        vm.prank(bob);
        vault.redeem(4392, bob, bob);

        assertEq(underlying.balanceOf(bob), 10930);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 0);

        // Sanity check
        assertEq(underlying.balanceOf(address(vault)), 0);
    }
}
