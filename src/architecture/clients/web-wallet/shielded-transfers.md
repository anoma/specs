<h1> Shielded Transfers In Web Client</h1>

Shielded transfers are based on [MASP](https://github.com/anoma/masp) and allows users of Anoma to performs transactions where only the recipient sender and a holder of a viewing key can see the transactions details. It is based on the specifications defined at [Shielded execution](../../ledger/shielded-execution/masp.md).

- [Code](#code)
- [Relation to MASP/Anoma CLI](#relation-to-maspanoma-cli)
- [The interface](#the-interface)
  - [create_master_shielded_account](#create_master_shielded_account)
  - [*create_master_shielded_account (WIP)*](#create_master_shielded_account-wip)
  - [get_shielded_balance](#get_shielded_balance)
  - [create_shielded_transfer](#create_shielded_transfer)
  - [NodeWithNextId](#nodewithnextid)
  - [NodeWithNextId::decode_transaction_with_next_tx_id](#nodewithnextiddecode_transaction_with_next_tx_id)



## Code
The code for interacting with the shielded transfers is split in 2 places:
* `anoma-wallet` (TypeScript)
  * capturing the user interactions
  * providing user feedback
  * fetching the existing MASP transactions from the ledger 
* `masp-web` (Rust)
  * generating shielded transfers
  * encrypting/decrypting data
  * utilising [MASP crate](https://github.com/anoma/masp)

```
packages
│   ├── masp-web                # MASP specific Rust code
│   ├── anoma-wallet            # anoma web wallet
```

## Relation to MASP/Anoma CLI
The feature set and logic between the CLI and the web client should be the same. There are however a few differences that are listed here:
* When optimizing the shielded interaction. We need to fetch and persist the existing shielded transfers in the client. For this the CLI is using the file system of the operating system while the web client will either have to store that data directly to the persistance mechanism of the browser (localhost or indexedDB) or to those through a virtual filesystem that seems compliant to WASI interface.
* In the current state the network calls will have to happen from the TypeScript code outside of the Rust and WASM. So any function calls to the shielded transfer related code in Rust must accept arrays of byte arrays that contains the newly fetched shielded transfers.
* There are limitations to the system calls when querying the CPU core count in the web client, so the sub dependencies of MASP using Rayon will be limited.

## The interface

currently the `masp-web` exposes the following API

### create_master_shielded_account
```rust
pub fn create_master_shielded_account(
    alias: String,
    seed_phrase: String,
    password: Option<String>,
) -> JsValue
```
* creates a shielded master account
* takes an optional password

### *create_master_shielded_account (WIP)* 
```rust
pub fn create_derived_shielded_account(
    alias: String,
    seed_phrase: String,
    master_shielded_account: AccountToDeriveFrom,
) -> JsValue
```
* creates a shielded master account
* takes an optional password

### get_shielded_balance
```rust
pub fn get_shielded_balance(
    shielded_transactions: JsValue,
    spending_key_as_string: String,
    token_address: String,
) -> Option<u64>
```
* returns a shielded balance for a `spending_key_as_string` `token_address` pair
* requires the past transfers as an input

### create_shielded_transfer
```rust
pub fn create_shielded_transfer(
    shielded_transactions: JsValue,
    spending_key_as_string: Option<String>,
    payment_address_as_string: String,
    token_address: String,
    amount: u64,
    spend_param_bytes: &[u8],
    output_param_bytes: &[u8],
) -> Option<Vec<u8>>
```
* returns a shielded transfer, based on the passed in data
* requires the past transfers as an input

### NodeWithNextId
```rust
pub struct NodeWithNextId {
    pub(crate) node: Option<Vec<u8>>,
    pub(crate) next_transaction_id: Option<String>,
}
```
* This is a utility type that is used when the TypeScript code is fetching the existing shielded transfers and extracting the id if the next shielded transfer to be fetched. The returned data from ledfer is turned to this type, so that the TypeScript can read the id of the next transfer and fetch it.

### NodeWithNextId::decode_transaction_with_next_tx_id
```rust
pub fn decode_transaction_with_next_tx_id(transfer_as_byte_array: &[u8]) -> JsValue
```
* accepts the raw byte array returned from the ledger when fetching for shielded transfers and returns `NodeWithNextId` as `JsValue`