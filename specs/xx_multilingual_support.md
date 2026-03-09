# Multilingual Support

## 1. Overview

### 1.1 Summary

This specification defines first-class multilingual support for the Family Chores App. The app will support English, Spanish, and Portuguese across core user-facing flows, including onboarding, authentication, family management, PIN prompts, validation errors, and shared invite messaging. Localization must be built as a platform capability rather than a one-off string replacement so future languages can be added without structural rework.

### 1.2 Business Context

The current product is hard-coded in English while the target household and broader market are multilingual. Language friction in onboarding, family setup, and parental controls directly harms activation and trust. Spanish support is essential for Latin American usage, and Portuguese support expands accessibility for Brazil and Portuguese-speaking families. This work also reduces future copy churn by centralizing text management.

### 1.3 Scope

**In scope:**
- Flutter localization infrastructure using ARB-based generated localizations
- App support for `en`, `es`, and `pt`
- Device locale detection with fallback to English
- Optional in-app language override persisted locally
- Localization of all current Phase 2 user-facing strings
- Localization of validation, snackbar, dialog, and empty-state text
- Localization of invite share text and deep-link related messaging
- Localization test strategy for unit, widget, and integration coverage
- Developer conventions for adding new localized strings

**Out of scope:**
- Right-to-left layout support
- Locale-specific number/date formatting for analytics dashboards beyond Flutter `intl` defaults
- Server-side localized push notifications
- Dynamic translation download
- AI or machine-generated translations at runtime
- Additional languages beyond English, Spanish, and Portuguese

### 1.4 References

- `specs/00_project_foundation.md` -- app architecture, feature structure, dependency rules
- `specs/08_phase2_foundations.md` -- app initialization, DI, routing
- `specs/09_firebase_auth.md` -- auth flows to localize
- `specs/10_family_onboarding.md` -- onboarding and family setup copy
- `specs/11_member_profiles.md` -- profile switching and member management flows
- `specs/12_pin_system.md` -- PIN entry and protection messaging
- `specs/16_deep_links.md` -- join flow and shareable link messaging
- `docs/development-rules.md` -- naming, testing, and implementation conventions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| I18N-001 | App supports English, Spanish, and Portuguese | High | Supported locales are registered and generated localizations compile successfully |
| I18N-002 | Device locale is used by default | High | App starts in the device language when it matches `en`, `es`, or `pt` |
| I18N-003 | Unsupported device locales fall back to English | High | Device locale outside supported list resolves to English copy |
| I18N-004 | User can override language in app settings | High | Selecting a language updates UI immediately and persists across app restarts |
| I18N-005 | Phase 2 screens are fully localized | High | No hard-coded user-facing English remains in auth, onboarding, family, profile, PIN, and settings screens |
| I18N-006 | Validation and error messages are localized | High | Form validation, snackbar failures, and permission messages are shown in the active language |
| I18N-007 | Share invite message is localized | Medium | Share sheet text uses translated copy while preserving the invite URL |
| I18N-008 | Deep-link join flow messaging is localized | Medium | Join screen labels and invalid/in-use code feedback respect active locale |
| I18N-009 | Locale change does not require re-login | Medium | Switching language updates the active app session without auth reset |
| I18N-010 | Developers add new strings through localization resources only | High | New user-facing copy is stored in ARB files and accessed through generated localizations |
| I18N-011 | Translation keys support placeholders | High | Dynamic content such as member names and invite codes use typed placeholders in generated localization APIs |
| I18N-012 | Platform localization delegates are configured correctly | High | Material, Cupertino, and Widgets localization delegates are registered in `MaterialApp` |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| I18N-NFR-001 | Locale switch responsiveness | Time from selection to visible UI update | < 200ms |
| I18N-NFR-002 | Translation coverage | User-facing strings localized in supported scope | 100% |
| I18N-NFR-003 | Regression safety | Localization-related widget and unit coverage | >= 80% of localization-aware business/UI paths |
| I18N-NFR-004 | Extensibility | Effort to add a fourth language | No architectural changes required |

### 2.3 Assumptions

- The app already uses Flutter `flutter_localizations` and `intl`, so no new localization framework is required.
- Current copy volume is still manageable enough for a one-time extraction from hard-coded strings.
- Translation content will be reviewed by a human speaker before release.
- Persisted app settings can be stored locally with the existing preferences approach.

### 2.4 Constraints

- Localization must preserve clean architecture boundaries and avoid passing `BuildContext` into domain or data layers.
- Business/domain failures should remain code-based internally; UI-facing messages must be mapped to localized presentation strings.
- Shared URLs, invite codes, and other protocol values must not be translated.
- Locale persistence must work offline.

---

## 3. Use Cases

### UC-001: Device Starts in Supported Locale
- **Actor**: Parent user
- **Preconditions**: Device language is Spanish, Portuguese, or English
- **Main Flow**:
  1. User launches the app for the first time.
  2. App resolves the device locale.
  3. App loads matching localized resources.
  4. User sees onboarding and auth screens in that language.
- **Alternative Flows**:
  - Device locale is regional variant such as `es_CO` or `pt_BR`; app resolves to base language.
- **Postconditions**: App content is shown in the detected supported language.
- **Exceptions**:
  - If locale is unsupported, app falls back to English.

### UC-002: User Overrides Language in Settings
- **Actor**: Parent user
- **Preconditions**: User is signed in and can access settings
- **Main Flow**:
  1. User opens settings.
  2. User selects English, Spanish, or Portuguese.
  3. App persists selection locally.
  4. UI rebuilds with the new locale immediately.
  5. On next app launch, the chosen locale is restored.
- **Alternative Flows**:
  - User selects "System default"; app clears manual override and returns to device locale.
- **Postconditions**: Chosen language remains active across sessions.
- **Exceptions**:
  - If persistence fails, app keeps current locale and shows a localized error.

### UC-003: Invite Share Text Uses Active Language
- **Actor**: Parent user
- **Preconditions**: Family exists and invite code generation succeeds
- **Main Flow**:
  1. User taps the share action.
  2. App generates or fetches invite code.
  3. App composes localized share text with the URL.
  4. System share sheet opens.
- **Alternative Flows**:
  - If invite generation fails, a localized snackbar is shown.
- **Postconditions**: Shared message is readable in the active app language.
- **Exceptions**:
  - URL remains unchanged regardless of locale.

### UC-004: Validation Error Appears in Selected Language
- **Actor**: Parent user
- **Preconditions**: App locale is set to Spanish or Portuguese
- **Main Flow**:
  1. User submits an invalid form.
  2. Validation logic emits field or failure codes.
  3. Presentation layer maps those codes to localized messages.
  4. User sees localized inline or snackbar feedback.
- **Alternative Flows**:
  - Generic unknown failures map to a localized fallback message.
- **Postconditions**: Errors are understandable in the active locale.
- **Exceptions**:
  - Internal exception details are never shown directly to users.

---

## 4. Architectural Design

### 4.1 Current State

- The app uses `MaterialApp.router` and already includes `flutter_localizations` and `intl` in dependencies.
- User-facing text is primarily hard-coded in widget files and some repository/presentation layers.
- There is no locale state object, no generated localization class, and no settings-level language selection.
- Error and validation messages are currently embedded as English strings in failures and UI code.

### 4.2 Proposed Changes

Add a localization layer with these components:

1. `l10n/` resources
- Add `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, and `lib/l10n/app_pt.arb`.
- Use Flutter gen-l10n to generate a strongly typed `AppLocalizations` class.

2. Locale state management
- Add a presentation-level locale cubit or controller under `lib/shared` or `lib/core/presentation`.
- Persist manual locale override in `SharedPreferences`.
- Support `system`, `en`, `es`, and `pt` selection.

3. App integration
- Configure `MaterialApp.router` with:
  - `localizationsDelegates`
  - `supportedLocales`
  - `localeResolutionCallback`
  - `locale` from the locale cubit when a manual override exists

4. String extraction
- Replace hard-coded user-facing strings in:
  - auth screens/blocs
  - onboarding
  - family setup/join/home/settings
  - profile switcher/member flows
  - PIN setup/entry
  - deep-link and invite share messaging

5. Failure-to-copy mapping
- Keep failure classes code-oriented.
- Add presentation mappers that translate failure codes into localized messages using `AppLocalizations`.

### 4.3 Component Interactions

```text
MaterialApp
  -> LocaleCubit / LocaleController
  -> AppLocalizations delegates
  -> Feature screens read localized strings from context
  -> FailureMessageMapper converts domain failures to localized copy
  -> Settings screen updates persisted locale preference
```

### 4.4 Data Model Changes

Add local preference storage only:

| Key | Type | Description |
|-----|------|-------------|
| `app_locale_override` | `String?` | `null` = system default, otherwise `en`, `es`, or `pt` |

No Firestore schema or backend changes are required.

### 4.5 API Changes

No external API contract changes.

Internal API additions:
- `LocaleRepository` or equivalent abstraction for loading/saving locale preference
- `AppLocalizations` generated accessors
- Optional `FailureMessageMapper` or `LocalizedFailureResolver`

---

## 5. Impact Analysis

### 5.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/app/app.dart` | Update | Medium | Add localization delegates and locale binding |
| `lib/main.dart` | Update | Low | Ensure locale controller initialized early if needed |
| `lib/l10n/` | New | Low | New translation resources |
| Settings feature | Update | Medium | Add language selector UI and persistence |
| Auth presentation | Update | Medium | Replace hard-coded strings |
| Family presentation | Update | Medium | Replace hard-coded labels, errors, and share copy |
| PIN presentation | Update | Medium | Replace parent-only prompts and errors |
| Error presentation mapping | New/Update | High | Prevent English-only errors leaking from failures |
| Widget tests | Update | Medium | Pump app with target locale and assert localized copy |

### 5.2 Dependencies

- Flutter gen-l10n tooling
- `flutter_localizations`
- `intl`
- Existing preferences mechanism for persistence

### 5.3 Breaking Changes

- Any direct assertions against English literals in tests will need updates.
- Presentation code that currently depends on hard-coded strings will need refactors.
- Failure messages stored directly inside domain failures may need to move toward code-based mapping.

### 5.4 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hard-coded strings remain in scattered widgets | High | Medium | Run repository-wide string audit and add review checklist |
| Domain failures remain English-only | High | High | Introduce centralized failure-to-localized-copy mapping |
| Locale switching causes stale UI state | Medium | Medium | Keep locale in app-level reactive state and add widget tests |
| Translations diverge semantically across languages | Medium | Medium | Require human review for Spanish and Portuguese strings |
| Placeholder formatting errors break runtime messages | Medium | Medium | Use typed ARB placeholders and test generated APIs |
| Future language addition causes duplicated patterns | Low | Medium | Standardize ARB naming and key conventions now |

---

## 6. Functional Tests

### 6.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| I18N-FT-001 | Device locale resolution | Device locale is `es_CO` | App starts | Spanish localization is selected | High |
| I18N-FT-002 | Unsupported locale fallback | Device locale is `fr_FR` | App starts | English localization is selected | High |
| I18N-FT-003 | Manual locale override persistence | User selects Portuguese | App restarts | Portuguese remains active | High |
| I18N-FT-004 | Settings updates UI immediately | User is on settings screen | User selects Spanish | Current screen rebuilds with Spanish copy | High |
| I18N-FT-005 | Auth screens localized | Locale is Portuguese | Sign-in screen renders | Title, buttons, and validation are Portuguese | High |
| I18N-FT-006 | Family join error localized | Locale is Spanish | Join family fails | Snackbar/error copy is Spanish | High |
| I18N-FT-007 | Invite share message localized | Locale is Portuguese | User taps share | Shared text is Portuguese and URL is unchanged | Medium |
| I18N-FT-008 | Failure message mapping | Network failure code is emitted | UI resolves failure | Localized fallback appears for active locale | High |
| I18N-FT-009 | System default reset | User previously chose Spanish | User resets to system default | Device locale controls language again | Medium |
| I18N-FT-010 | Generated localization placeholders | Invite code placeholder exists | Localized method is called | Output contains translated text with correct inserted value | High |

### 6.2 Edge Cases

- Device locale contains country variant not explicitly listed, such as `pt_PT` or `es_MX`
- Locale preference is corrupted or contains unsupported value
- UI changes language while a snackbar or dialog is already open
- Errors originating from background operations surface after locale change
- Share text includes diacritics and must remain correct across Android and iOS

### 6.3 Integration Test Requirements

- Pump the app with a fake saved locale and verify app-level locale selection.
- Verify settings language selection persists via preferences.
- Verify at least one end-to-end onboarding path in Spanish.
- Verify at least one parent-protected path in Portuguese.
- Verify deep-link join screen renders localized labels after cold start.

---

## 7. Implementation Recommendations

### 7.1 Suggested Approach

1. Introduce localization infrastructure first.
2. Add locale persistence and app-level state management.
3. Extract strings from Phase 2 screens in vertical slices:
   - auth/onboarding
   - family/profile
   - PIN/settings
4. Introduce failure message mapping so presentation no longer depends on English literals.
5. Add tests as each slice lands.

Recommended technical choices:
- Use Flutter’s built-in gen-l10n instead of a third-party package.
- Keep locale selection in a small app-level cubit.
- Store stable failure codes in domain/data layers and resolve copy only in presentation.
- Use descriptive ARB keys such as `signInTitle`, `joinFamilyButton`, `pinEntryPrompt`.

### 7.2 Estimated Effort

- Localization infrastructure and app wiring: 1 day
- String extraction for current Phase 2 UI: 1-2 days
- Settings locale selector and persistence: 0.5-1 day
- Failure mapping refactor: 1 day
- Tests and polish: 1 day

Estimated total: 4-6 engineering days plus translation review.

### 7.3 Suggested Order of Implementation

1. Add `l10n.yaml` and ARB resources for `en`, `es`, `pt`
2. Wire localization delegates into app root
3. Add locale persistence and settings selector
4. Localize auth and onboarding
5. Localize family/profile/PIN/deep-link flows
6. Refactor failure message mapping
7. Add widget and integration coverage

---

## 8. Open Questions

- [ ] Should the app expose a visible language selector during onboarding, or only in settings?
- [ ] Is Brazilian Portuguese (`pt_BR`) the intended Portuguese baseline, or should copy remain region-neutral `pt`?
- [ ] Should “System default” be a fourth visible option in the settings UI?
- [ ] Are notification and email templates expected to follow the same locale preference in a later phase?

## 9. References

- Flutter internationalization guide
- Flutter gen-l10n tooling
- Existing project specs 08-16 for currently implemented user-facing flows

---
*Generated by Software Architect Analyst*
*Date: 2026-03-09*
