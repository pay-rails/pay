# Using Pay with Paddle

## Paddle Sandbox

The [Paddle Sandbox](https://developer.paddle.com/getting-started/sandbox) can be used for testing your Paddle integration.

```html
<script src="https://cdn.paddle.com/paddle/paddle.js"></script>
<script type="text/javascript">
  Paddle.Environment.set('sandbox');
  Paddle.Setup({ vendor: <%= Pay::Paddle.vendor_id %> });
</script>
```
