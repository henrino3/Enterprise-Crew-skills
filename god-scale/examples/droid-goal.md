# Example Droid goal

Goal: Fix validation on a checkout form using a configured Droid custom model.

```bash
god-scale init --goal "Fix checkout validation" --mode droid
god-scale mission add "Repair invalid email and empty address validation" --accept "npm test -- checkout" --scope "Checkout form, validation helper, and tests only."
god-scale run --mode droid --model "custom:Your-Model-0"
```
