# Metamask Testing Guide

This directory contains comprehensive test scripts for Metamask wallet integration with the Pay gem. Tests are organized into three layers: **unit**, **integration**, and **E2E**.

## Test Files

- **[unit_test.rb](unit_test.rb)** — Unit tests with mocked Web3 calls
- **[integration_test.rb](integration_test.rb)** — Integration tests with Pay gem models
- **[e2e_test.rb](e2e_test.rb)** — End-to-end browser automation tests
- **[../support/metamask.rb](../support/metamask.rb)** — Test helpers and fixtures

## Test Wallets

The tests use two test wallets:

- **Wallet 1**: `0xacA92E438df0B2401fF60dA7E4337B687a2435DA`
- **Wallet 2**: `0xDc810078c9B23e41f9B204EC63ae5289AA865117`
- **Merchant**: `0x9876543210987654321098765432109876543210`

## Running Tests

### 1. Unit Tests (Mocked Web3)

Unit tests mock all Web3/Ethers.js calls and test isolated logic.

```bash
# Run all unit tests
ruby -Itest test/pay/metamask/unit_test.rb

# Run specific test
ruby -Itest test/pay/metamask/unit_test.rb -n test_validates_ethereum_address_format

# With verbose output
ruby -Itest test/pay/metamask/unit_test.rb -v
```

**What's tested:**
- Wallet address validation
- Message signing and recovery
- Transaction mocking
- Gas estimation
- Balance checking
- Error handling

**Example output:**
```
Finished in 0.123 seconds, 81.30 runs/s, 81.30 assertions/s.
10 runs, 10 assertions, 0 failures, 0 errors, 0 skips
```

### 2. Integration Tests (Mocked + Pay Gem Models)

Integration tests combine mocked Web3 with Pay gem models (customers, charges, subscriptions).

```bash
# Run all integration tests
ruby -Itest test/pay/metamask/integration_test.rb

# Run specific test
ruby -Itest test/pay/metamask/integration_test.rb -n test_customer_can_connect_metamask_wallet_to_pay_account

# With verbose output
ruby -Itest test/pay/metamask/integration_test.rb -v
```

**What's tested:**
- Wallet connection to customer accounts
- Creating charges via Metamask
- Managing multiple wallets
- Subscriptions with Metamask
- Transaction syncing
- Gas fee estimation
- Refunds

**Example output:**
```
Finished in 0.456 seconds, 32.89 runs/s, 49.34 assertions/s.
15 runs, 22 assertions, 0 failures, 0 errors, 0 skips
```

### 3. E2E Tests (Browser Automation)

E2E tests use Playwright to automate a real browser with Metamask extension.

#### Prerequisites

1. **Install Playwright gem:**
   ```bash
   bundle add playwright-ruby-client
   ```

2. **Install browsers:**
   ```bash
   bundle exec playwright install
   ```

3. **Get Metamask Flask (dev version):**
   - Download: https://metamask.io/flask/
   - Or use MetamaskProvider mock/test utilities

4. **Start test server:**
   ```bash
   RAILS_ENV=test rails server -p 3000
   ```

#### Running E2E Tests

```bash
# Run all E2E tests (with headless: false to see browser)
PLAYWRIGHT=true ruby -Itest test/pay/metamask/e2e_test.rb

# Run specific E2E test
PLAYWRIGHT=true ruby -Itest test/pay/metamask/e2e_test.rb -n test_user_can_connect_metamask_wallet_to_payment_form

# Run in headless mode
PLAYWRIGHT=true HEADLESS=true ruby -Itest test/pay/metamask/e2e_test.rb

# With verbose output
PLAYWRIGHT=true ruby -Itest test/pay/metamask/e2e_test.rb -v
```

**Environment Variables:**
- `PLAYWRIGHT=true` — Enable E2E tests (skipped if not set)
- `HEADLESS=true` — Run in headless mode (default: false)
- `TEST_URL=http://localhost:3000` — Server URL (default shown)
- `DEBUG=true` — Enable debug logging

**What's tested:**
- Wallet connection UI flows
- Message signing UI
- Payment completion
- Multi-wallet management
- Transaction history viewing
- Receipt download
- Subscription creation
- Error handling UI
- Network switching

**Example output:**
```
✓ User can connect metamask wallet to payment form (2.5s)
✓ User signs message to verify wallet ownership (3.2s)
✓ User can complete payment with metamask (4.1s)
...
15 passed (45.2s)
```

## Test Fixtures

Fixtures are stored in `test/fixtures/files/metamask/`:

- **wallet_connected.json** — Wallet connection event
- **transaction_confirmed.json** — Successful transaction event
- **transaction_failed.json** — Failed transaction event
- **wallet_disconnected.json** — Wallet disconnection event

Load fixtures in tests:
```ruby
event_data = json_fixture("wallet_connected")
```

## Test Helpers

Helper methods are defined in `test/support/metamask.rb`:

```ruby
# Create payment method
create_metamask_payment_method(customer, wallet_address)

# Create fake transaction
fake_transaction_result(tx_hash, status: 1)

# Stub Web3 calls
stub_wallet_balance(wallet, 5.0)
stub_send_transaction()
stub_gas_price(50000000000)

# Verify addresses
stub_recover_address(message, signature, wallet)
```

## Running All Tests Together

```bash
# Unit + Integration tests (no browser required)
rake test test/pay/metamask/unit_test.rb test/pay/metamask/integration_test.rb

# All three test types
PLAYWRIGHT=true rake test:metamask
```

## Mocking Metamask Locally

For local development without the Metamask extension, use:

```bash
# Mock Metamask provider in browser console
window.ethereum = {
  isMetaMask: true,
  selectedAddress: "0xacA92E438df0B2401fF60dA7E4337B687a2435DA",
  chainId: "0x1",
  request: async (args) => {
    // Handle eth_requestAccounts, eth_sign, eth_sendTransaction, etc.
  }
};
```

Or use **ethers.js** mock provider:
```javascript
import { MockProvider } from '@ethersproject/providers';
const provider = new MockProvider();
```

## Debugging Tests

### Debug failing unit test:
```bash
ruby -Itest test/pay/metamask/unit_test.rb -n test_name --debug
```

### Inspect browser state in E2E test:
```ruby
@page.pause  # Pauses execution, opens inspector
@page.screenshot(path: 'debug.png')
```

### Check stubbing:
```ruby
# Verify stub was called
Web3::Eth.expects(:send_transaction).once
```

## Common Issues

### Issue: "User denied message signature"
**Solution**: E2E test requires user interaction. Use MetamaskProvider mock or approve in browser.

### Issue: "insufficient funds for gas * price + value"
**Solution**: Tests use mocked balance. Adjust `stub_wallet_balance()` in test setup.

### Issue: Playwright timeout
**Solution**: Increase timeout or add waits:
```ruby
@page.wait_for_selector("[data-testid='element']", timeout: 30000)
```

### Issue: VCR cassette not recording
**Solution**: E2E tests don't use VCR by default. Record manually or mock Metamask responses.

## CI/CD Integration

```yaml
# .github/workflows/test-metamask.yml
name: Metamask Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.0
      - run: bundle install
      - run: bundle exec rails db:test:prepare
      - run: ruby -Itest test/pay/metamask/unit_test.rb
      - run: ruby -Itest test/pay/metamask/integration_test.rb
      # E2E tests require browser/display, skip in CI or use xvfb-run
      # - run: xvfb-run -a bundle exec ruby -Itest test/pay/metamask/e2e_test.rb
```

## Test Coverage

Run with coverage:
```bash
COVERAGE=true ruby -Itest test/pay/metamask/unit_test.rb
```

Coverage files: `coverage/`

## Resources

- [Metamask Developer Docs](https://docs.metamask.io/)
- [ethers.js Documentation](https://docs.ethers.org/)
- [Web3.py vs ethers.js vs web3.js](https://ethereum.org/en/developers/docs/programming-languages/)
- [Playwright Ruby Client](https://github.com/YusukeIwaki/playwright-ruby)
- [MetamaskProvider Testing](https://github.com/MetaMask/metamask-extension/wiki/Testing-an-Ethereum-dApp)

## Adding New Tests

### Template for unit test:
```ruby
test "does something with metamask" do
  stub_gas_price(50000000000)
  
  result = Web3::Eth.gas_price
  
  assert_equal 50000000000, result
end
```

### Template for integration test:
```ruby
test "customer can do something with metamask" do
  payment_method = create_metamask_payment_method(@pay_customer)
  
  charge = @pay_customer.charges.create!(
    processor_id: "tx_123",
    amount_in_cents: 50000,
    payment_method: payment_method
  )
  
  assert charge.persisted?
end
```

### Template for E2E test:
```ruby
test "user can do something with metamask" do
  @page.goto("#{@base_url}/path")
  @page.wait_for_load_state("networkidle")
  
  @page.click("button:has-text('Action')")
  @page.wait_for_selector("[data-testid='result']", timeout: 10000)
  
  assert @page.locator("[data-testid='result']").visible?
end
```

## Contributing

When adding new tests:
1. Add unit test first (mock layer)
2. Add integration test (Pay gem layer)
3. Add E2E test if user-facing (browser layer)
4. Update fixtures as needed
5. Document in this README
6. Run full test suite before PR
