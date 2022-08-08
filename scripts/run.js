const hre = require("hardhat");

// To deploy the contract locally with the help of Hardhat.
const main = async () => {
  const rsvpContractFactory = await hre.ethers.getContractFactory("Web3RSVP");
  const rsvpContract = await rsvpContractFactory.deploy();
  await rsvpContract.deployed();
  console.log("Contract deployed to:", rsvpContract.address);

  // To get deployer wallets addresses from Hardhat to test the contract.
  const [deployer, address1, address2] = await hre.ethers.getSigners();

  // The data to use as input for the creation of the event. The last element is a given IPFS reference.
  let deposit = hre.ethers.utils.parseEther("1");
  let maxCapacity = 3;
  let timeStamp = 1718926200;
  let eventDataCID =
    "bafybeibhwfzx6oo5rymsxmkdxpmkfwyvbjrrwcl7cekmbzlupmp5ypkyfi";

  // Creating the event. txn.wait will return data about the transaction, including an array of the emitted events which can be logged into the console. Here is where the eventId is given.
  let txn = await rsvpContract.createNewIdEvent(
    timeStamp,
    deposit,
    maxCapacity,
    eventDataCID
  );

  let wait = await txn.wait();
  console.log("NEW EVENT CREATED:", wait.events[0].event, wait.events[0].args);

  let eventID = wait.events[0].args.eventID;
  console.log("EVENT ID:", eventID);

  txn = await rsvpContract.createNewRSVP(eventID, { value: deposit });
  wait = await txn.wait();
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

  txn = await rsvpContract
    .connect(address1)
    .createNewRSVP(eventID, { value: deposit });
  wait = await txn.wait();
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

  txn = await rsvpContract
    .connect(address2)
    .createNewRSVP(eventID, { value: deposit });
  wait = await txn.wait();
  console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

  txn = await rsvpContract.confirmAllAttendees(eventID);
  wait = await txn.wait();
  wait.events.forEach((event) =>
    console.log("CONFIRMED:", event.args.attendeeAddress)
  );

  // wait 10 years
  await hre.network.provider.send("evm_increaseTime", [15778800000000]);

  txn = await rsvpContract.withdrawUnclaimedDeposits(eventID);
  wait = await txn.wait();
  console.log("WITHDRAWN:", wait.events[0].event, wait.events[0].args);
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();
