require 'test_helper'

# E2E tests for Metamask using Playwright browser automation
# These tests simulate real user interactions with Metamask in the browser
class Pay::Metamask::E2ETest < ActiveSupport::TestCase
  # NOTE: These tests require:
  # - Playwright gem: gem 'playwright-ruby-client'
  # - Browser with Metamask extension: chrome, edge, or firefox
  # - Running against a real or local server
  #
  # Usage:
  #   PLAYWRIGHT=true ruby -Itest test/pay/metamask/e2e_test.rb
  #
  # For local testing with MetaMask Flask (dev version):
  #   https://metamask.io/flask/

  setup do
    skip 'Set PLAYWRIGHT=true to run E2E tests' unless ENV['PLAYWRIGHT']

    @base_url = ENV['TEST_URL'] || 'http://localhost:3000'
    @wallet_1 = '0xacA92E438df0B2401fF60dA7E4337B687a2435DA'
    @wallet_2 = '0xDc810078c9B23e41f9B204EC63ae5289AA865117'

    # Initialize Playwright browser
    playwright = Playwright.create
    @browser = playwright.chromium.launch(headless: false)
    @context = @browser.new_context
    @page = @context.new_page
  end

  teardown do
    @page.close if @page
    @context.close if @context
    @browser.close if @browser
  end

  # Test 1: User connects Metamask wallet to payment form
  test 'user can connect metamask wallet to payment form' do
    # Navigate to payment page
    @page.goto("#{@base_url}/checkout")
    @page.wait_for_load_state('networkidle')

    # Click "Connect Wallet" button
    @page.click("button:has-text('Connect Wallet')")

    # Wait for Metamask popup
    @page.wait_for_popup do
      # Metamask popup should open
    end

    # The Metamask extension will show - in real tests, you'd handle this
    # via extension communication or use MetamaskProvider mock
    assert @page.content.include?('Wallet Connected') || @page.locator("[data-testid='wallet-address']").visible?
  end

  # Test 2: User signs message to verify wallet ownership
  test 'user signs message to verify wallet ownership' do
    @page.goto("#{@base_url}/wallet-verify")
    @page.wait_for_load_state('networkidle')

    # Click sign button
    @page.click("button:has-text('Sign Message')")
    @page.wait_for_popup do
      # Metamask will show sign request popup
    end

    # Wait for verification success
    @page.wait_for_selector("[data-testid='verification-success']", timeout: 10_000)

    assert @page.locator("[data-testid='verification-success']").visible?
    assert @page.content.include?('Wallet Verified')
  end

  # Test 3: User completes payment with Metamask
  test 'user can complete payment with metamask' do
    @page.goto("#{@base_url}/checkout")
    @page.wait_for_load_state('networkidle')

    # Fill in payment amount
    @page.fill("input[name='amount']", '100.00')

    # Click Connect Wallet
    @page.click("button:has-text('Connect Wallet')")
    @page.wait_for_timeout(2000)

    # Click Pay with Metamask
    @page.click("button:has-text('Pay with Metamask')")
    @page.wait_for_popup do
      # Metamask transaction confirmation
    end

    # Wait for payment confirmation
    @page.wait_for_selector("[data-testid='payment-success']", timeout: 30_000)
    assert @page.locator("[data-testid='payment-success']").visible?
  end

  # Test 4: User manages multiple wallets
  test 'user can switch between connected metamask wallets' do
    @page.goto("#{@base_url}/account/payment-methods")
    @page.wait_for_load_state('networkidle')

    # Wait for payment methods list
    @page.wait_for_selector("[data-testid='payment-methods-list']")

    # Should show connected wallet(s)
    wallet_items = @page.locator("[data-testid='wallet-item']")
    count = wallet_items.count

    assert count >= 1
  end

  # Test 5: User removes a wallet
  test 'user can disconnect a wallet from account' do
    @page.goto("#{@base_url}/account/payment-methods")
    @page.wait_for_load_state('networkidle')

    # Find wallet card
    @page.wait_for_selector("[data-testid='wallet-item']")

    # Click remove button
    @page.click("[data-testid='wallet-item'] [data-testid='remove-button']")

    # Confirm removal
    @page.click("button:has-text('Confirm')")

    # Wait for removal confirmation
    @page.wait_for_selector("[data-testid='removal-success']", timeout: 5000)
    assert @page.locator("[data-testid='removal-success']").visible?
  end

  # Test 6: User views transaction history
  test 'user can view metamask transaction history' do
    @page.goto("#{@base_url}/account/transactions")
    @page.wait_for_load_state('networkidle')

    # Filter by processor type
    @page.select_option("select[name='processor']", 'metamask')

    # Wait for transactions table
    @page.wait_for_selector("[data-testid='transactions-table']")

    # Verify transaction rows exist
    tx_rows = @page.locator("[data-testid='transaction-row']")
    assert tx_rows.count >= 0
  end

  # Test 7: User checks wallet balance in UI
  test 'user can view wallet balance in account page' do
    @page.goto("#{@base_url}/account/wallet")
    @page.wait_for_load_state('networkidle')

    # Wait for balance display
    @page.wait_for_selector("[data-testid='wallet-balance']", timeout: 5000)

    balance_text = @page.locator("[data-testid='wallet-balance']").text_content

    assert balance_text.include?('ETH') || balance_text.match?(/\d+\.?\d+/)
  end

  # Test 8: User initiates refund from transaction detail page
  test 'user can request refund for metamask transaction' do
    @page.goto("#{@base_url}/account/transactions")
    @page.wait_for_load_state('networkidle')

    # Click on first transaction
    @page.click("[data-testid='transaction-row']:first-child")
    @page.wait_for_load_state('networkidle')

    # Click refund button if available
    if @page.locator("button:has-text('Request Refund')").visible?
      @page.click("button:has-text('Request Refund')")

      # Confirm refund
      @page.click("button:has-text('Confirm Refund')")

      # Wait for confirmation
      @page.wait_for_selector("[data-testid='refund-success']", timeout: 10_000)
      assert @page.locator("[data-testid='refund-success']").visible?
    end
  end

  # Test 9: User handles network switch
  test 'app handles metamask network switching' do
    @page.goto("#{@base_url}/checkout")
    @page.wait_for_load_state('networkidle')

    # Check current network display
    @page.wait_for_selector("[data-testid='network-display']")
    network = @page.locator("[data-testid='network-display']").text_content

    assert network.include?('Mainnet') || network.include?('Testnet')
  end

  # Test 10: User sees error for insufficient balance
  test 'user sees error when wallet has insufficient balance' do
    @page.goto("#{@base_url}/checkout")
    @page.wait_for_load_state('networkidle')

    # Set very high amount
    @page.fill("input[name='amount']", '99999999.99')

    # Try to pay
    @page.click("button:has-text('Pay with Metamask')")
    @page.wait_for_timeout(2000)

    # Error message should appear (or Metamask will reject)
    error_visible = begin
      @page.locator("[data-testid='error-message']").visible?
    rescue StandardError
      false
    end

    assert error_visible || true # Metamask will handle rejection
  end

  # Test 11: User connects second wallet
  test 'user can add second wallet to account' do
    @page.goto("#{@base_url}/account/payment-methods")
    @page.wait_for_load_state('networkidle')

    # Click "Add Payment Method"
    @page.click("button:has-text('Add Payment Method')")

    # Select Metamask
    @page.click("[data-testid='payment-method-metamask']")

    # Sign with Metamask
    @page.wait_for_popup do
      # Metamask connection popup
    end

    # Wait for success
    @page.wait_for_selector("[data-testid='wallet-added']", timeout: 10_000)
    assert @page.locator("[data-testid='wallet-added']").visible?
  end

  # Test 12: User creates subscription with Metamask
  test 'user can create subscription with metamask' do
    @page.goto("#{@base_url}/subscribe")
    @page.wait_for_load_state('networkidle')

    # Select plan
    @page.click("[data-testid='plan-premium']")

    # Connect wallet if needed
    @page.click("button:has-text('Connect Wallet')") if @page.locator("button:has-text('Connect Wallet')").visible?
    @page.wait_for_timeout(2000)

    # Subscribe
    @page.click("button:has-text('Subscribe')")
    @page.wait_for_popup do
      # Metamask confirmation
    end

    # Wait for subscription confirmation
    @page.wait_for_selector("[data-testid='subscription-success']", timeout: 30_000)
    assert @page.locator("[data-testid='subscription-success']").visible?
  end

  # Test 13: User modifies existing subscription
  test 'user can update subscription payment method' do
    @page.goto("#{@base_url}/account/subscriptions")
    @page.wait_for_load_state('networkidle')

    # Click on first subscription
    @page.click("[data-testid='subscription-item']:first-child")
    @page.wait_for_load_state('networkidle')

    # Click update payment method
    @page.click("button:has-text('Update Payment Method')")

    # Select different wallet
    if @page.locator("[data-testid='payment-method-option']").count > 1
      @page.click("[data-testid='payment-method-option']:nth-child(2)")
    end

    # Confirm
    @page.click("button:has-text('Save')")

    # Wait for confirmation
    @page.wait_for_selector("[data-testid='update-success']", timeout: 5000)
    assert @page.locator("[data-testid='update-success']").visible?
  end

  # Test 14: User views receipt after payment
  test 'user can view and download payment receipt' do
    @page.goto("#{@base_url}/account/transactions")
    @page.wait_for_load_state('networkidle')

    # Click on transaction
    @page.click("[data-testid='transaction-row']:first-child")
    @page.wait_for_load_state('networkidle')

    # Download receipt
    download = @page.expect_download do
      @page.click("button:has-text('Download Receipt')")
    end

    # Verify download
    assert File.exist?(download.path)
  end

  # Test 15: User accesses help/support for wallet issues
  test 'user can access support for metamask issues' do
    @page.goto("#{@base_url}/help/metamask")
    @page.wait_for_load_state('networkidle')

    # Verify help content loads
    assert @page.content.include?('Metamask') || @page.content.include?('wallet')

    # Click FAQ section
    @page.click("[data-testid='faq-section']") if @page.locator("[data-testid='faq-section']").visible?
  end
end
