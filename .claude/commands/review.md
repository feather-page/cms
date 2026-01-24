# Code Review Command

Review the specified code for quality, security, and Rails best practices.

## Usage

```
/review [file_or_directory]
```

## Review Checklist

### 1. Code Quality
- [ ] Methods are short (< 15 lines)
- [ ] Single responsibility principle followed
- [ ] No deep nesting (max 2-3 levels)
- [ ] Descriptive naming used
- [ ] Guard clauses for early returns

### 2. Rails Conventions
- [ ] Controllers are thin
- [ ] Business logic in Service Objects
- [ ] Models focused on data concerns
- [ ] Strong parameters used correctly
- [ ] N+1 queries prevented (check for `includes`)

### 3. Security (OWASP)
- [ ] No SQL injection vulnerabilities
- [ ] Input validation present
- [ ] Authorization checks in place
- [ ] No sensitive data in logs
- [ ] CSRF protection for forms

### 4. Testing
- [ ] Tests exist for new code
- [ ] Edge cases covered
- [ ] Factories used correctly
- [ ] No `create` when `build_stubbed` suffices

### 5. Documentation
- [ ] Complex logic explained
- [ ] Public APIs documented
- [ ] GLOSSARY.md updated if needed

## Output Format

For each issue found:

```
## [Severity: High/Medium/Low] Issue Title

**File:** path/to/file.rb:line_number

**Problem:**
Brief description of the issue.

**Suggestion:**
How to fix it with code example if helpful.
```

## After Review

1. Summarize findings by severity
2. Highlight critical issues that block merge
3. Note positive aspects of the code
4. Suggest improvements (not blocking)
