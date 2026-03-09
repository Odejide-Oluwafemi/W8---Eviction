# Week 8 - Eviction Test Day 1

## Project Description
To refactor the existing monolithic EvictionVault smart contract into a secure, modular architecture and implement immediate mitigation for critical security vulnerabilities within a three-hour time frame.
The core task involves the decomposition of the single-file EvictionVault contract into a logically structured, multi-file project.

Concurrently, the following critical vulnerabilities must be addressed and secured:
* setMerkleRoot Callable by Anyone
* emergencyWithdrawAll Public Drain
* pause/unpause Single Owner Control
* receive() Uses tx.origin
* withdraw & claim Uses .transfer
* Timelock Execution (This is listed as a check, but often implies a potential issue if not correctly implemented)

### Deliverables
* A complete, modular project structure (eliminating the single-file monolith).
* Clean contract compilation (verified via forge build).
* A suite of 4–6 basic positive tests that pass successfully.
* A README file detailing the implemented fixes and the current state of the contract.

---

## My Implemented Fixes
* I split the project into two files: ```Multisig.sol``` (which handles the multisig logic), the ```Vault.sol``` (which contains the vault logic)
* Refactored ```require``` statements into more gas-efficient Custom Errors
* Changed all variables to ```private``` and created an appropriate getter function for them
* Fixed the TimeLock logic in the ```executeTransaction``` function
* Implemented Access Control using modifiers.
* Wrote test suites to ensure logic correctness