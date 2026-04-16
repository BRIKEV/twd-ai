# TWD Test Writing — Advanced Component Mocking

This reference covers component mocking for replacing third-party SDKs (payment providers, maps, video players, chat widgets) and other components that communicate through callbacks. Read this when:

- A component is wrapped with `MockedComponent` from `twd-js/ui`
- You need to test callback flows (success, failure, error handlers)
- You're refactoring an SDK wrapper to make it testable

For the core test-writing API (mockRequest, assertions, waitFor, state isolation, Sinon stubbing), see `test-writing.md`.

## Section 1: Component Mocking Basics

`twd-js/ui` exports `MockedComponent` — a wrapper that lets tests substitute a component at runtime. The test calls `twd.mockComponent("name", Component)` to register a replacement, and `twd.clearComponentMocks()` to clear all registered mocks.

> **Mock before visit**: Call `twd.mockComponent()` BEFORE `twd.visit()`, just like `mockRequest`. Use the `.twd.test.tsx` extension when writing JSX in mock implementations.

```tsx
// In your component — wrap with MockedComponent
import { MockedComponent } from "twd-js/ui";

function Dashboard() {
  return (
    <MockedComponent name="HeavyChart">
      <HeavyChart data={data} />
    </MockedComponent>
  );
}
```

```tsx
// In your test — mock BEFORE twd.visit()
twd.mockComponent("HeavyChart", () => (
  <div data-testid="mock-chart">Mocked Chart</div>
));
await twd.visit("/dashboard");

// Clear in beforeEach (already part of the standard beforeEach)
twd.clearComponentMocks();
```

This example replaces a heavy component with static HTML. That works when the component doesn't communicate back to the parent. For components that DO communicate (callbacks, refs), see Section 2.

## Section 2: How MockedComponent Forwards Props

**Critical**: `MockedComponent` replaces its **children** with the mock and passes the **children's props** to the mock. The mock receives whatever props the child component would receive — NOT the props of `MockedComponent` itself.

```tsx
// WRONG — MockedComponent wraps a div, the mock receives the div's props (just className)
<MockedComponent name="payment">
  <div className="w-full">
    <div ref={checkoutRef} />
  </div>
</MockedComponent>

// RIGHT — MockedComponent wraps a component that receives the callback props
function PaymentContent(props: PaymentProps) {
  // ... SDK init using props.onCompleted, props.onFailed ...
  return <div ref={checkoutRef} />;
}

export function PaymentDropIn(props: PaymentProps) {
  return (
    <MockedComponent name="payment">
      <PaymentContent {...props} />
    </MockedComponent>
  );
}
```

When mocked, the mock component receives `PaymentContent`'s props — including all callbacks. This is how interactive mocks work (Section 3).

## Section 3: Interactive Mocks with Callback Forwarding

The core pattern for testing third-party SDK integrations. Instead of replacing a component with static HTML, replace it with buttons that invoke the same callbacks the SDK would invoke:

```tsx
twd.mockComponent("payment", ({
  onCompleted,
  onFailed,
  onError,
}: {
  onCompleted: () => Promise<void>;
  onFailed: (code: string) => void;
  onError: (message: string) => void;
}) => {
  return (
    <div>
      <button onClick={() => onCompleted()}>Pay</button>
      <button onClick={() => onFailed("Refused")}>Fail Payment</button>
      <button onClick={() => onError("SDK crashed")}>Error</button>
    </div>
  );
});
```

Each button simulates a different SDK outcome. The parent's callback handlers fire exactly as they would in production — calling APIs, sending analytics, navigating, showing errors. The test clicks a button and asserts on the result.

## Section 4: Refactor for Testability — Lifting Callbacks from SDK Wrappers

When a third-party SDK (payment providers, maps, video players, chat widgets) controls its own UI and communicates through callbacks, the business logic often ends up inside the SDK wrapper component. This makes it untestable.

The pattern:

1. **Identify the callbacks** the SDK fires (success, failure, error, etc.)
2. **Move the business logic** (API calls, analytics, navigation, error state) from the SDK wrapper to the parent component
3. **Make the wrapper thin** — it initializes the SDK and wires each callback to a prop
4. **Wrap with `MockedComponent`** using the inner-component pattern (Section 2)
5. **Build an interactive mock** with buttons per callback (Section 3)

**Before — untestable** (business logic lives inside the SDK wrapper):

```tsx
function PaymentDropIn({ session, orderId, cart }) {
  useEffect(() => {
    SDK.init({
      session,
      onCompleted: async () => {
        await moveToPending(orderId);      // API call
        await sendPurchaseEvent(cart);      // analytics
        navigate("/success");               // navigation
      },
      onFailed: (result) => {
        sendErrorEvent(cart, result.code);  // analytics
        setError("Payment failed");         // error state
      },
    });
  }, []);
  return <div ref={ref} />;
}
```

**After — testable** (thin wrapper + parent owns business logic):

```tsx
// Thin wrapper — just SDK init, all callbacks forwarded as props
function PaymentContent({ session, onCompleted, onFailed, onError }) {
  useEffect(() => {
    SDK.init({
      session,
      onPaymentCompleted: () => onCompleted(),
      onPaymentFailed: (r) => onFailed(r.code),
      onError: (e) => onError(e.message),
    });
  }, []);
  return <div ref={ref} />;
}

export function PaymentDropIn(props) {
  return (
    <MockedComponent name="payment">
      <PaymentContent {...props} />
    </MockedComponent>
  );
}

// Parent owns business logic
function CheckoutPage() {
  const handleCompleted = async () => {
    await moveToPending(orderId);
    await sendPurchaseEvent(cart);
    navigate("/success");
  };
  // ... handleFailed, handleError ...

  return <PaymentDropIn session={session} onCompleted={handleCompleted} ... />;
}
```

Now tests click "Pay" and verify `moveToPending` was called, analytics fired, and navigation happened — all without the SDK.

## Section 5: When to Use Component Mocking

Not every third-party integration needs component mocking. Use it when:

- The component renders third-party UI you can't control (payment forms, map embeds, video players)
- The component communicates through callbacks that trigger your business logic
- You need to test what happens AFTER the third-party interaction (API calls, analytics, navigation, errors)

Don't use it when:

- You can test the behavior through API mocking alone (most cases)
- The component is a simple UI library component (buttons, inputs, modals)
- The third-party SDK has a test mode that works reliably
