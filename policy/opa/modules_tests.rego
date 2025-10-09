package truckercore.modules

import data.truckercore.modules

test_allow_main_ok {
  modules.allow with input as {"branch":"main","approvals":2,"checks_succeeded":true,"functions_egress":["allowlisted.domain.tld"]}
}

test_deny_egress {
  not modules.allow with input as {"branch":"main","approvals":2,"checks_succeeded":true,"functions_egress":["bad.example.com"]}
  modules.deny[_]
}
