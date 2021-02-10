# Test cases

## Test Item: Adding tokens + setting prices

### General Requirements:

1. The token must not have been created earlier.
2. Entrypoint (launchToken) can only be call by Factory.
3. Only a contract Controller can be a Factory administrator.
4. Ensures that qToken is in qTokens set.

**Scope**: Test various ways to add new tokens

**Action**: Invoke the LaunchToken, SatOracle, SafeMint entrypoints.

**Verification Steps**: Verify the tokens added and the initial state is correct.

**Scenario 1**: Test Adding tokens when

- [x] the token have been created earlier.
- [x] the launchToken call by another contract
- [x] the controller is not admin in Factory
- [x] the qToken is not in qTokens set.
