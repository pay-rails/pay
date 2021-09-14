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
