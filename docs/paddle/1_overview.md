# Using Pay with Paddle

Paddle works differently than most of the other payment processors so it comes with some limitations and differences.

* You cannot create a Customer from the API
* Checkout only happens via iFrame or hosted page
* Cancelling a subscription cannot be resumed
* Payment methods can only be updated while a subscription is active
* Paddle customers are not reused when a user re-subscribes

## Paddle Sandbox

The [Paddle Sandbox](https://developer.paddle.com/getting-started/sandbox) can be used for testing your Paddle integration.

```html
<script src="https://cdn.paddle.com/paddle/paddle.js"></script>
<script type="text/javascript">
  Paddle.Environment.set('sandbox');
  Paddle.Setup({ vendor: <%= Pay::Paddle.vendor_id %> });
</script>
```

## Paddle Public Key

Paddle uses public/private keys for webhook verification. You can find
your public key [here for Production](https://vendors.paddle.com/public-key)
and [here for Sandbox](https://sandbox-vendors.paddle.com/public-key).

Pay uses a Base64 encoded version of this public key. To generate one, download
the public key from the link above and save it in the root of your Rails app as `paddle.pem`, then open a `rails console`

```ruby
paddle_public_key = OpenSSL::PKey::RSA.new(File.read("paddle.pem"))
Base64.encode64(paddle_public_key.to_der)
```

Copy what's displayed and then insert that into an environment variable or your secrets file. The `paddle.pem` file can then be deleted.

If you get an error such as `OpenSSL::PKey::RSAError (Neither PUB key nor PRIV key: nested asn1 error)` when you may have a space at the start of the public key.