import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect, assert } from 'chai';
import { ethers } from "hardhat";
import { GlangerStaking } from '../typechain-types/contracts/GlangerStaking';
import { RewardToken } from '../typechain-types/contracts/Contracts/RewardToken';
import { GlangerNFT } from '../typechain-types/contracts/Contracts/GlangerNFT';
import { configs } from '../utils/configs';
import { utils } from 'ethers';

describe("Glanger Staking", () => {
    let nft: GlangerNFT;
    let reward: RewardToken;
    let staking: GlangerStaking;
    let _baseTokenURI = configs.baseTokenURI;
    let _openBoxBeforeTokenURI = configs.openBoxBeforeURI;
    let _maxTotalSupply = configs.totlaSupply;
    let _openBoxTime = configs.openBoxTime;
    let _executeAddress : string;
    let _executor: SignerWithAddress;
    let _account2: SignerWithAddress;
    let _owner: SignerWithAddress;
    let _account3: SignerWithAddress;


    beforeEach(async () => {
        const [owner, account1, account2, account3] = await ethers.getSigners();
        _executeAddress = account1.address;
        _executor = account1;
        _account2 = account2;
        _account3 = account3;
        _owner = owner;

        const glangerNFT = await ethers.getContractFactory("GlangerNFT");
        nft = await glangerNFT.deploy(_baseTokenURI, _openBoxBeforeTokenURI, _maxTotalSupply, _openBoxTime, account1.address);
        await nft.deployed();

        const RewardToken = await ethers.getContractFactory("RewardToken");
        reward = await RewardToken.deploy("Rewards Token", "RT");
        await reward.deployed();

        const GlangerStaking = await ethers.getContractFactory("GlangerStaking");
        staking = await GlangerStaking.deploy(nft.address, reward.address);
        await staking.deployed();

        await nft.connect(_account2).mint(_account2.address, 6);
        await nft.connect(_account3).mint(_account3.address, 6);

        await nft.connect(_account2).setApprovalForAll(staking.address, true, {"from": _account2.address})
        await nft.connect(_account3).setApprovalForAll(staking.address, true, {"from": _account3.address})

    })

    describe("Glanger Staking", () => {

        it("stake", async () => {
            await reward.transfer(staking.address, 1000000);
            await staking.connect(_account2).stake(1,{"value":utils.parseEther("0")});
            await staking.connect(_account2).stake(2,{"value":utils.parseEther("0")});
            await staking.connect(_account2).stake(3,{"value":utils.parseEther("0")});
            await staking.connect(_account2).stake(4,{"value":utils.parseEther("0")});
            await staking.connect(_account2).stake(5,{"value":utils.parseEther("0")});
            const stakeInfo = await staking.userStakeInfo(_account2.address);
            expect(stakeInfo[0]).to.be.equal(5);
        })

        it("stakeBatch", async () => {
            await reward.transfer(staking.address, 1000000);
            await staking.connect(_account2).stakeBatch([0,1,2,3,4,5]);
            const stakeInfo = await staking.userStakeInfo(_account2.address);
            expect(stakeInfo[0]).to.be.equal(6);
        })

        it("withdraw", async () => {
            await staking.connect(_account2).stake(0);
            await staking.connect(_account2).stake(1);
            //time passed
            await ethers.provider.send("evm_increaseTime", [24*60*60]);

            await staking.connect(_account2).withdraw(0);
            await staking.connect(_account2).withdraw(1);

            const stakeInfo2 = await staking.userStakeInfo(_account2.address);
            console.log(stakeInfo2);
            expect(stakeInfo2[0]).to.be.equal(0);
        })

        it("withdrawBatch", async () => {
            await staking.connect(_account2).stakeBatch([0,1]);
            // await staking.connect(_account2).withdrawBatch([0,1]);
            //time passed
            await ethers.provider.send("evm_increaseTime", [24*60*60]);

            await staking.connect(_account2).withdrawBatch([0,1]);

            const stakeInfo2 = await staking.userStakeInfo(_account2.address);
            // console.log(stakeInfo2);
            expect(stakeInfo2[0]).to.be.equal(0);
        })

        it("claimRewards", async () => {
            await staking.connect(_account2).stakeBatch([0,1]);

            //time passed
            await ethers.provider.send("hardhat_mine", ["0x1"]);

            const balance_before_claim = await reward.connect(_account2).balanceOf(_account2.address)
            await reward.transfer(staking.address, 1000000);
            await staking.connect(_account2).claimRewards()
            const balance_after_claim = await reward.connect(_account2).balanceOf(_account2.address)
            // console.log("before: ", balance_before_claim, " after: ", balance_after_claim);
        })

        it("setRewardsPerHour", async () => {
            const rewardPerHour = ethers.utils.parseUnits("200000");
            await staking.setRewardsPerHour(rewardPerHour);
        })

        it("userStakeInfo", async () => {
            await staking.connect(_account2).stakeBatch([0,1]);

            //time passed
            await ethers.provider.send("hardhat_mine", ["0x1"]);

            const stakeInfo = await staking.userStakeInfo(_account2.address);
            // console.log(stakeInfo);
            expect(stakeInfo[0]).to.be.equal(2);
            expect((stakeInfo[2]).length).to.be.equal(2);
        })
    })
    
});