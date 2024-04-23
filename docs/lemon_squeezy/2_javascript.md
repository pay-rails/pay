# Lemon Squeezy Javascript

Lemon.js is used for Lemon Squeezy. It is a Javascript library that allows you to embed
a checkout into your website.

## Setup

Add the Lemon.js script in your application layout.

```html
<script src="https://app.lemonsqueezy.com/js/lemon.js" defer></script>
```

## Generating a Checkout Button

With Lemon.js initialized, it will automatically look for any elements with the `lemonsqueezy-button`
class and turn them into a checkout button.

It doesn't support sending attributes, so to customize the checkout button and session, you'll need to
add additional parameters to the URL. You can view the [supported fields here](https://docs.lemonsqueezy.com/help/checkout/prefilling-checkout-fields) and the [custom data field here](https://docs.lemonsqueezy.com/help/checkout/passing-custom-data).

You'll need to replace `STORE` with your store URL slug & `UUID` with the UUID of the plan you want to use, which
can be found by clicking Share on the product in Lemon Squeezy's dashboard.

Passing the customer's email address to the checkout URL will link it to the customer created in Lemon Squeezy.

```html
<a
  class="lemonsqueezy-button"
  href="https://STORE.lemonsqueezy.com/checkout/buy/UUID?checkout[email]=<%= CGI.escape(@user.email) %>">
  Sign up to Plan
</a>
```

## Hosted Checkout

Hosted checkout is the default checkout method. It will open a new window to the Lemon Squeezy website.
If Lemon.js is loaded, and the `lemonsqueezy-button` class is added to the link, it will open the checkout
in an overlay.

## Overlay Checkout

To enable overlay checkout, add `embed=1` to the above URL.
