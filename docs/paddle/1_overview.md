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

There are 3 ways that you can set the public key in Pay. 

In either example, you can set the environment variable or in Rails credentials.

### File

You can download the public key from the link above and save it to a location which your Rails application
can access. Then set the `PADDLE_PUBLIC_KEY_FILE` to the location of the file.

### Key

Set the `PADDLE_PUBLIC_KEY` environment variable with your public key. Replace any spaces with `\n` otherwise
you may get a `OpenSSL::PKey::RSAError` error.

### Base64 Encoded Key

Or you can set a Base64 encoded version of the key. To do this, download a copy of your public key
then open a `rails console` and enter the following:

```ruby
paddle_public_key = OpenSSL::PKey::RSA.new(File.read("paddle.pem"))
Base64.encode64(paddle_public_key.to_der)
```

Copy what's displayed and set the `PADDLE_PUBLIC_KEY_BASE64` environment variable.
