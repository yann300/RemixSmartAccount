"use strict";

import { expect } from "chai";
import { Contract, Signer, BrowserProvider, ContractFactory, parseUnits } from "ethers";

const getArtifact = async (contractName: string, signer: number) => {
    const metadata = JSON.parse(await remix.call('fileManager', 'getFile', `./artifacts/${contractName}.json`))
    return new ContractFactory(metadata.abi, metadata.data.bytecode.object, signer)
}

const getSigners = async () => {
    const provider = new BrowserProvider(web3Provider)
    return [await provider.getSigner(0), await provider.getSigner(1), await provider.getSigner(2)]
}

describe("RemixSmartAccount", function () {
    let RemixSmartAccount: Contract;
    let MockERC1155: Contract;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    
    
    before(async function () {
        [owner, addr1, addr2] = await getSigners()
        
        // Deploy MockERC1155
        const MockERC1155Factory = await getArtifact("MockERC1155", owner);
        MockERC1155 = await MockERC1155Factory.deploy(await owner.getAddress());
        await MockERC1155.waitForDeployment();

        // Deploy RemixSmartAccount with MockERC1155 address
        const RemixSmartAccountFactory = await getArtifact("RemixSmartAccount", owner);
        RemixSmartAccount = await RemixSmartAccountFactory.deploy();
        await RemixSmartAccount.waitForDeployment();
    });
    
    describe("Deployment", function () {
        it("Should deploy RemixSmartAccount and MockERC1155", async function () {
            expect(await RemixSmartAccount.getAddress()).to.not.be.undefined;
            expect(await MockERC1155.getAddress()).to.not.be.undefined;
        });
    });
    
    describe("Token Restrictions", function () {
        it("Should only accept USDC tokens", async function () {
            // Mint some MockERC1155 to addr1
            await MockERC1155.connect(owner).mint(await addr1.getAddress(), 0, parseUnits("1000", 6), '0x');
            
            console.log(parseUnits("9", 0))
            const balanceBefore = await MockERC1155.balanceOf(await RemixSmartAccount.getAddress(), 0)
            console.log(balanceBefore)
            // Try to send USDC to RemixSmartAccount
            await MockERC1155.connect(addr1).safeTransferFrom(await addr1.getAddress(), await RemixSmartAccount.getAddress(), 0, parseUnits("7", 0), '0x');
            console.log('test')
            // Check if RemixSmartAccount received USDC
            const balance = await MockERC1155.balanceOf(await RemixSmartAccount.getAddress(), 0);
            expect(balance).to.equal(parseUnits("7", 0));
        });
    });
    
    describe("Balance Limit", function () {
        it("Should not exceed the USDC balance limit", async function () {
            // Try to send more USDC (exceeding limit)
            await expect(
                MockERC1155.connect(addr1).safeTransferFrom(await addr1.getAddress(), await RemixSmartAccount.getAddress(), 0, parseUnits("4", 0), '0x')
            ).to.be.revertedWith("ERC1155 balance would exceed 10 tokens limit");
        });
    });
    /*
    describe("Transaction Execution", function () {
        it("Should execute a valid transaction", async function () {
            // Mint some MockERC1155 to RemixSmartAccount
            await MockERC1155.connect(owner).mint(await RemixSmartAccount.getAddress(), parseUnits("10", 6));
            
            // Deploy a simple Spender contract to receive USDC
            const SpenderFactory = await getArtifact("Spender", owner);
            const Spender = await SpenderFactory.deploy();
            await Spender.waitForDeployment();
            
            // Prepare transaction data to send USDC to Spender
            const usdcAddress = await MockERC1155.getAddress();
            const spenderAddress = await Spender.getAddress();
            const amount = parseUnits("5", 6);
            
            const transferData = MockERC1155.interface.encodeFunctionData("transfer", [spenderAddress, amount]);
            
            // Execute transaction via RemixSmartAccount
            await RemixSmartAccount.connect(owner).execute(usdcAddress, 0, transferData);
            
            // Check if Spender received USDC
            const spenderBalance = await MockERC1155.balanceOf(spenderAddress);
            expect(spenderBalance).to.equal(amount);
        });
    });
    */
    
});