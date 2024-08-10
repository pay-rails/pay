<p align="center"><img src="docs/images/logo.svg" height="50px"></p>

# 💳 Pay - Payments engine for Ruby on Rails

[![Build Status](https://github.com/pay-rails/pay/workflows/Tests/badge.svg)](https://github.com/pay-rails/pay/actions) [![Gem Version](https://badge.fury.io/rb/pay.svg)](https://badge.fury.io/rb/pay)

<img src="docs/images/stripe_partner_badge.svg" height="26px">

Pay is a payments engine for Ruby on Rails 6.0 and higher.

⚠️  **Upgrading?** Check the [UPGRADE](UPGRADE.md) guide for required changes and/or migration when upgrading from a previous version of Pay.

## 🧑‍💻 Tutorial

Want to see how Pay works? Check out our video getting started guide.

<a href="https://www.youtube.com/watch?v=hYlOmqyJIgc" target="_blank"><img width="50%" src="http://i3.ytimg.com/vi/hYlOmqyJIgc/maxresdefault.jpg"></a>

## 🏦 Payment Processors

Our supported payment processors are:

- Stripe ([SCA Compatible](https://stripe.com/docs/strong-customer-authentication) using API version `2022-11-15`)
- Paddle (SCA Compatible & supports PayPal)
- Braintree (supports PayPal)
- Lemon Squeezy (supports PayPal)
- [Fake Processor](docs/fake_processor/1_overview.md) (used for generic trials without cards, free subscriptions, testing, etc)

Want to add a new payment provider? Contributions are welcome.

> We make our best attempt to standardize the different payment providers. They function differently so keep that in mind if you plan on doing more complex payments. It would be best to stick with a single payment provider in that case so you don't run into discrepancies.

## 📚 Docs

* [Installation](docs/1_installation.md)
* [Configuration](docs/2_configuration.md)
* **Usage**
  * [Customers](docs/3_customers.md)
  * [Payment Methods](docs/4_payment_methods.md)
  * [Charges](docs/5_charges.md)
  * [Subscriptions](docs/6_subscriptions.md)
  * [Routes & Webhooks](docs/7_webhooks.md)
  * [Customizing Pay Models](docs/8_customizing_models.md)

* **Payment Processors**
  * [Stripe](docs/stripe/1_overview.md)
  * [Braintree](docs/braintree/1_overview.md)
  * [Paddle](docs/paddle_billing/1_overview.md)
  * [Lemon Squeezy](docs/lemon_squeezy/1_overview.md)
  * [Fake Processor](docs/fake_processor/1_overview.md)
* **Marketplaces**
  * [Stripe Connect](docs/marketplaces/stripe_connect.md)
* **Contributing**
  * [Adding A Payment Processor](docs/contributing/adding_a_payment_processor.md)

## 🙏 Contributing

If you have an issue you'd like to submit, please do so using the issue tracker in GitHub. In order for us to help you in the best way possible, please be as detailed as you can.

For those using devcontainers, if you want to test the application with different databases:
1. Uncomment the `DATABASE_URL` corresponding to the database type you wish to use in the `.devcontainer/devcontainer.json` file.
2. Rebuild the devcontainer, which will configure the application to use the selected database for your development environment.

If you'd like to open a PR please make sure the following things pass:

```ruby
bin/rails db:test:prepare
bin/rails test
bundle exec standardrb
```

## 📝 License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
