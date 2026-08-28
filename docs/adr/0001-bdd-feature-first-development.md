# BDD feature-first development

Status: accepted

Development without an agreed specification produced features that did not match what was asked for, and
no living record of the intended behaviour. We write Gherkin scenarios in `features/` and get them
confirmed before implementing, so the specification is executable and doubles as documentation.

The default `rake` task runs RSpec and Cucumber together; the search path is set in `config/cucumber.yml`.
