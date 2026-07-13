# Creates AlmaHub code-structure improvement issues in Linear.
# Requires: LINEAR_API_KEY environment variable (Personal API key from Linear Settings)
#
# Usage:
#   $env:LINEAR_API_KEY = "lin_api_..."
#   .\scripts\linear\create_code_structure_issues.ps1
#
# Optional:
#   $env:LINEAR_PROJECT_NAME = "Almahub"   # default: Almahub
#   $env:LINEAR_TEAM_KEY = "ALM"           # fallback if project has no team

param(
    [string]$ProjectName = $(if ($env:LINEAR_PROJECT_NAME) { $env:LINEAR_PROJECT_NAME } else { "Almahub" }),
    [string]$TeamKey = $(if ($env:LINEAR_TEAM_KEY) { $env:LINEAR_TEAM_KEY } else { "" })
)

$ErrorActionPreference = "Stop"
$apiKey = $env:LINEAR_API_KEY
if (-not $apiKey) {
    Write-Error "LINEAR_API_KEY is not set. Create a Personal API key in Linear: Settings -> Account -> Security & access -> Personal API keys"
}

function Invoke-LinearGraphQL {
    param(
        [string]$Query,
        [hashtable]$Variables = @{}
    )

    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 20 -Compress
    $response = Invoke-RestMethod `
        -Uri "https://api.linear.app/graphql" `
        -Method Post `
        -Headers @{ Authorization = $apiKey; "Content-Type" = "application/json" } `
        -Body $body

    if ($response.errors) {
        $msg = ($response.errors | ForEach-Object { $_.message }) -join "; "
        throw "Linear API error: $msg"
    }

    return $response.data
}

function Get-ProjectAndTeam {
    param([string]$Name, [string]$FallbackTeamKey)

    $query = @'
query Projects {
  projects(first: 50) {
    nodes {
      id
      name
      slugId
      teams { nodes { id name key } }
    }
  }
}
'@

    $data = Invoke-LinearGraphQL -Query $query
    $project = $data.projects.nodes | Where-Object {
        $_.name -ieq $Name -or $_.slugId -ieq $Name
    } | Select-Object -First 1

    if (-not $project) {
        $available = ($data.projects.nodes | ForEach-Object { $_.name }) -join ", "
        throw "Project '$Name' not found. Available projects: $available"
    }

    $team = $project.teams.nodes | Select-Object -First 1
    if (-not $team -and $FallbackTeamKey) {
        $teamQuery = @'
query Team($key: String!) {
  team(id: $key) { id name key }
}
'@
        $teamData = Invoke-LinearGraphQL -Query $teamQuery -Variables @{ key = $FallbackTeamKey }
        $team = $teamData.team
    }

    if (-not $team) {
        throw "No team linked to project '$($project.name)'. Set LINEAR_TEAM_KEY to your team identifier (e.g. ALM)."
    }

    return @{ Project = $project; Team = $team }
}

function New-LinearIssue {
    param(
        [string]$TeamId,
        [string]$ProjectId,
        [string]$Title,
        [string]$Description,
        [int]$Priority = 3,
        [string[]]$Labels = @()
    )

    $labelIds = @()
    foreach ($labelName in $Labels) {
        $labelQuery = @'
query Labels($teamId: ID!) {
  team(id: $teamId) {
    labels(filter: { name: { eq: $name } }) {
      nodes { id name }
    }
  }
}
'@
        # Linear filter syntax varies; create label if missing via issueLabels on team
        $existing = Invoke-LinearGraphQL -Query @"
query {
  issueLabels(filter: { name: { eq: `"$labelName`" } }) {
    nodes { id name }
  }
}
"@
        if ($existing.issueLabels.nodes.Count -gt 0) {
            $labelIds += $existing.issueLabels.nodes[0].id
        }
    }

    $input = @{
        teamId      = $TeamId
        projectId   = $ProjectId
        title       = $Title
        description = $Description
        priority    = $Priority
    }
    if ($labelIds.Count -gt 0) {
        $input.labelIds = $labelIds
    }

    $mutation = @'
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { id identifier title url }
  }
}
'@

    $result = Invoke-LinearGraphQL -Query $mutation -Variables @{ input = $input }
    if (-not $result.issueCreate.success) {
        throw "Failed to create issue: $Title"
    }

    return $result.issueCreate.issue
}

$issues = @(
    @{
        Title = "[Structure] Epic: Code structure & maintainability refactor"
        Priority = 2
        Description = @"
## Goal
Reduce god-widget complexity, eliminate duplication, and establish scalable architecture patterns across AlmaHub.

## Scope
- Split large dashboard/onboarding screens
- Introduce state management and routing
- Consolidate models and shared services
- Improve folder organization and test coverage gates

## Success criteria
- No screen file exceeds ~800 lines without a documented reason
- Single source of truth for onboarding models
- Shared auth/user services used by all dashboards
- CI runs `flutter analyze` on every PR
"@
    },
    @{
        Title = "[Structure] Split employee_dashboard.dart into feature modules"
        Priority = 2
        Description = @"
## Problem
`lib/screens/employee/employee_dashboard.dart` is ~3,100+ lines — profile, leave, policies, role listener, and UI are tightly coupled.

## Tasks
- [ ] Extract leave module (`features/leave/`)
- [ ] Extract policy module (`features/policies/`)
- [ ] Extract profile/photo module
- [ ] Extract shared sidebar/navigation widget
- [ ] Keep thin dashboard shell that composes modules

## Files
- `lib/screens/employee/employee_dashboard.dart`
"@
    },
    @{
        Title = "[Structure] Split hr_dashboard.dart into feature modules"
        Priority = 2
        Description = @"
## Problem
`lib/screens/hr/hr_dashboard.dart` is ~2,500+ lines mixing employee table, document cells, approve/reject, Excel export, and policy links.

## Tasks
- [ ] Extract employee table + filters
- [ ] Extract document preview cell widget
- [ ] Extract approve/reject/delete actions service
- [ ] Extract Excel export actions
- [ ] Thin HR dashboard shell

## Files
- `lib/screens/hr/hr_dashboard.dart`
"@
    },
    @{
        Title = "[Structure] Split employee_onboarding_wizard.dart into step modules"
        Priority = 2
        Description = @"
## Problem
`lib/screens/employee/employee_onboarding_wizard.dart` is ~3,400+ lines — largest file in the repo.

## Tasks
- [ ] Align employee wizard steps with existing HR step widgets where possible
- [ ] Extract per-step state and validation
- [ ] Extract shared wizard navigation/progress bar
- [ ] Move Firestore/Storage persistence to a dedicated service

## Files
- `lib/screens/employee/employee_onboarding_wizard.dart`
- `lib/screens/hr/step*.dart` (reuse candidates)
"@
    },
    @{
        Title = "[Structure] Split supervisor_dashboard.dart into feature modules"
        Priority = 3
        Description = @"
## Problem
`lib/screens/supervisor/supervisor_dashboard.dart` is ~2,200+ lines with hours tracking, performance scoring, and forwarding logic inline.

## Tasks
- [ ] Extract hours table and month selector
- [ ] Extract performance/overtime calculation utilities
- [ ] Extract forward-to-accountant workflow
- [ ] Reuse or share hours entry dialog logic cleanly

## Files
- `lib/screens/supervisor/supervisor_dashboard.dart`
- `lib/screens/supervisor/hours_entry_dialog.dart`
"@
    },
    @{
        Title = "[Structure] Introduce state management (Riverpod recommended)"
        Priority = 2
        Description = @"
## Problem
All state lives in `StatefulWidget` with direct Firestore calls. Role listeners, policy status, and leave data are duplicated across dashboards.

## Tasks
- [ ] Add `flutter_riverpod` dependency
- [ ] Create providers for: current user/role, employee profile, policies, leave
- [ ] Migrate one dashboard as pilot (employee recommended)
- [ ] Document provider conventions in README

## Benefits
- Testable business logic
- Less rebuild churn
- Shared realtime listeners
"@
    },
    @{
        Title = "[Structure] Add go_router for centralized navigation"
        Priority = 3
        Description = @"
## Problem
Navigation uses scattered `Navigator.push` / `pushReplacement` calls with no typed routes or deep-link support.

## Tasks
- [ ] Add `go_router` dependency
- [ ] Define routes: splash, login, welcome, role dashboards, onboarding, recruitment
- [ ] Add auth redirect guards
- [ ] Replace imperative navigation in auth flow first

## Files
- `lib/main.dart`
- `lib/screens/authentication/*`
- `lib/screens/role_selection_screen.dart`
"@
    },
    @{
        Title = "[Structure] Consolidate duplicate onboarding models"
        Priority = 2
        Description = @"
## Problem
Onboarding data models exist in two places:
- `lib/models/employee_onboarding_models.dart`
- `lib/screens/hr/employee_onboarding_models.dart`

HR steps import the screens copy; employee/accountant import the models copy — drift risk.

## Tasks
- [ ] Diff both files and merge into `lib/models/employee_onboarding_models.dart`
- [ ] Update all imports
- [ ] Delete duplicate file
- [ ] Run `flutter analyze` to verify
"@
    },
    @{
        Title = "[Structure] Extract AuthService and UserRepository"
        Priority = 2
        Description = @"
## Problem
Firebase Auth + Firestore user lookup + realtime role listener are copy-pasted across splash, role selection, and dashboards.

## Tasks
- [ ] Create `lib/core/auth/auth_service.dart`
- [ ] Create `lib/core/auth/user_repository.dart`
- [ ] Centralize: sign in/out, fetch AppUser, watch role changes
- [ ] Replace duplicated listeners in dashboards

## Reference
- `lib/models/user_model.dart`
- `lib/screens/role_selection_screen.dart`
"@
    },
    @{
        Title = "[Structure] Extract shared AppLogger utility"
        Priority = 4
        Description = @"
## Problem
Nearly every screen constructs its own `Logger(printer: PrettyPrinter(...))` with identical config.

## Tasks
- [ ] Create `lib/core/logging/app_logger.dart` with singleton/factory
- [ ] Replace per-file Logger instantiation
- [ ] Optionally disable verbose logging in release builds
"@
    },
    @{
        Title = "[Structure] Migrate Firestore doc IDs from employee name to UID"
        Priority = 3
        Description = @"
## Problem
`FirestoreService._generateDocIdFromName()` uses employee name as document ID — collision and rename risk.

## Tasks
- [ ] Use Firebase Auth UID as primary document key
- [ ] Store `fullName` as a field, not as doc ID
- [ ] Migration plan for existing Draft/EmployeeDetails docs
- [ ] Update Storage paths if tied to name-based folders

## Files
- `lib/services/firestore_service.dart`
- `lib/services/storage_service.dart`
"@
    },
    @{
        Title = "[Structure] Reorganize lib/ into core, features, and shared"
        Priority = 3
        Description = @"
## Proposed layout
```
lib/
  core/           # auth, logging, routing, theme
  features/
    employee/
    hr/
    supervisor/
    accountant/
    recruitment/
    policies/
  models/
  services/
  widgets/        # shared UI components
```

## Tasks
- [ ] Create folder scaffold
- [ ] Move files incrementally (one feature at a time)
- [ ] Update imports
- [ ] Avoid big-bang rename — use PR-sized moves
"@
    },
    @{
        Title = "[Structure] Extract shared UI design system"
        Priority = 4
        Description = @"
## Problem
Purple/indigo branding and card/button styles vary between HR, employee, and supervisor screens.

## Tasks
- [ ] Extract theme extensions (colors, text styles)
- [ ] Create shared widgets: `AppCard`, `AppPrimaryButton`, `EmptyState`, `LoadingOverlay`
- [ ] Align AppBar colors with `main.dart` seed theme
"@
    },
    @{
        Title = "[Structure] Replace broken default widget test"
        Priority = 3
        Description = @"
## Problem
`test/widget_test.dart` is still the Flutter counter-app template — it does not match this app and will fail.

## Tasks
- [ ] Replace with smoke test: app boots and shows splash/login
- [ ] Mock Firebase initialization or use `firebase_core` test mocks
- [ ] Add CI step: `flutter test`
"@
    },
    @{
        Title = "[Structure] Add unit tests for core services"
        Priority = 3
        Description = @"
## Scope
Add meaningful unit tests (not trivial asserts) for:
- [ ] `FirestoreService` — doc ID helpers, collection routing by status
- [ ] `PolicyService` — policy fetch/status logic
- [ ] `ExcelGenerationService` — output structure
- [ ] Role routing logic (Admin → role selection, Employee → dashboard)

## Setup
- Consider Firebase Emulator Suite for integration tests later
"@
    },
    @{
        Title = "[Structure] Add GitHub Actions CI (analyze + test)"
        Priority = 3
        Description = @"
## Tasks
- [ ] Add `.github/workflows/flutter_ci.yml`
- [ ] Steps: checkout, setup Flutter, `flutter pub get`, `flutter analyze`, `flutter test`
- [ ] Optional: `dart format --set-exit-if-changed`

## Note
Requires GitHub repo remote; adjust if using different CI provider.
"@
    },
    @{
        Title = "[Structure] Paginate Firestore queries in HR/supervisor tables"
        Priority = 4
        Description = @"
## Problem
Dashboards may load full collections into memory as employee count grows.

## Tasks
- [ ] Add Firestore pagination (`limit`, `startAfterDocument`)
- [ ] Infinite scroll or page controls in employee/hours tables
- [ ] Verify composite indexes in `firestore.indexes.json`
"@
    },
    @{
        Title = "[Structure] Store document metadata in Firestore (reduce Storage N+1)"
        Priority = 4
        Description = @"
## Problem
HR dashboard loads documents per employee row via Storage `listAll` — N+1 pattern.

## Tasks
- [ ] On upload, write doc metadata to Firestore (`documents` map on employee record)
- [ ] HR table reads metadata from Firestore
- [ ] Keep Storage as blob store only
"@
    }
)

Write-Host "Looking up Linear project '$ProjectName'..."
$ctx = Get-ProjectAndTeam -Name $ProjectName -FallbackTeamKey $TeamKey
$project = $ctx.Project
$team = $ctx.Team

Write-Host "Project: $($project.name) ($($project.id))"
Write-Host "Team:    $($team.name) [$($team.key)]"
Write-Host ""
Write-Host "Creating $($issues.Count) issues..."
Write-Host ""

$created = @()
foreach ($issue in $issues) {
    $result = New-LinearIssue `
        -TeamId $team.id `
        -ProjectId $project.id `
        -Title $issue.Title `
        -Description $issue.Description `
        -Priority $issue.Priority

    Write-Host "  $($result.identifier)  $($result.title)"
    Write-Host "  $($result.url)"
    Write-Host ""
    $created += $result
}

Write-Host "Done. Created $($created.Count) issues under project '$($project.name)'."
