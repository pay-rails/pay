# Paddle Javascript

Paddle.js v2 is used for Paddle Billing. It is a Javascript library that allows you to embed
Paddle Checkout into your website.

## Setup

```html
<script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
<script type="text/javascript">
  Paddle.Environment.set("sandbox");
  Paddle.Setup({
    // This can be hard-coded or set using environment variables/Rails credentials
    // It needs to be an integer, not a string
    seller: <%= Pay::Paddle.seller_id %>
  });
</script>
```

## Generating a Checkout Button

With Paddle.js initialized, it will automatically look for any elements with the `paddle_button`
class and turn them into a checkout button.

It supports sending HTML Data Attributes to customize the checkout button and session.

You can view the [supported attributes here](https://developer.paddle.com/paddlejs/html-data-attributes).

In this example, the `data-customer-id` attribute is set to the Paddle Customer ID. This is used
to link the newly created subscription to this customer.

The `data-items` attribute requires an array of items for this checkout. It also requires a
`priceId` and `quantity` for each item.

```html
<a href='#'
  class='paddle_button'
  data-display-mode='overlay'
  data-theme='none'
  data-locale='en'
  data-items='[
    {
      "priceId": "<%= plan.price_id %>",
      "quantity": 1
    }
  ]'
  data-customer-id="<%= @user.payment_processor.processor_id %>"
>
  Sign up to <%= plan.name %>
</a>
```

## Overlay Checkout

The overlay checkout is the default checkout method. It will open a modal on top of your website.

## Inline Checkout

Inline checkout can be enabled by setting the `data-display-mode` attribute to `inline`. This allows
you to have tighter integration within your application.

For more information, see the [Paddle documentation](https://developer.paddle.com/build/checkout/build-branded-inline-checkout).
