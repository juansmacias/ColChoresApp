# Category Management

## 1. Overview

### 1.1 Summary

This specification defines the Category Management feature -- the system for organizing tasks by household area (Kitchen, Bathroom, Yard, etc.). It covers the `Category` entity lifecycle, default category seeding, the `CategoryManagementCubit`, the CategoryManagementScreen (list with CRUD), the CategoryCreateScreen (name + icon + color picker), the category picker widget used in task creation, and the deletion guard logic. Categories provide visual organization and filtering for the task list.

### 1.2 Business Context

Categories help families mentally organize their chores by physical space or function. When Sofia sees the task list, category color strips and icons let her quickly scan which rooms need attention. Default categories cover the most common household areas, but families can create custom categories for their specific needs (e.g., "Garden Shed", "Homework", "Car"). Category management is a parent-only feature (PIN-gated).

### 1.3 Scope

**In scope:**
- `Category` entity (defined in `specs/18_task_domain.md`, referenced here)
- 8 default categories seeded on family creation
- `CategoryManagementCubit` with states and methods
- `CategoryManagementScreen` (list with swipe-to-delete)
- `CategoryCreateScreen` (name, icon picker, color picker)
- Category picker widget for task creation form
- Deletion guard (blocked if tasks reference category)
- Seeding integration with CreateFamily use case
- Icon picker grid (24 Material Icons)
- Color picker grid (12 pastel colors)

**Out of scope:**
- Task domain layer (see `specs/18_task_domain.md`)
- Task data layer (see `specs/19_task_data_layer.md`)
- Task creation screen (see `specs/21_task_creation_screen.md`)

### 1.4 References

- `specs/18_task_domain.md` -- Category entity, CategoryRepository interface, CreateCategoryParams, default categories
- `specs/19_task_data_layer.md` -- CategoryLocalDatasource, CategoryRemoteDatasource, CategoryRepositoryImpl
- `specs/17_phase3_foundations.md` -- Routes (`/categories`, `/categories/new`), PIN guard
- `specs/10_family_onboarding.md` -- CreateFamily use case (seeding integration point)
- `docs/design-system.md` -- Pastel color palette

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| CM-001 | 8 default categories seeded on family creation | High | Kitchen, Bathroom, Bedroom, Living Room, Yard, Laundry, Pets, General exist after family setup |
| CM-002 | Default categories cannot be deleted | High | Swipe-to-delete blocked, "Default categories cannot be deleted" message |
| CM-003 | Custom categories can be created | High | Name + icon + color saved, appears in category list |
| CM-004 | Custom categories can be deleted | High | Swipe-to-delete removes category (if no active tasks) |
| CM-005 | Deletion blocked if active tasks exist | High | "X tasks still use this category" error shown |
| CM-006 | Category list shows all family categories | High | Default and custom categories displayed |
| CM-007 | Category create validates name uniqueness | High | Duplicate name within family shows error |
| CM-008 | Category picker in task form shows categories | High | Horizontal chip row with all categories |
| CM-009 | Category picker "+ New" chip creates inline | Medium | Opens CategoryCreateScreen, returns new category |
| CM-010 | Categories sync to Firestore | High | Created categories appear on other devices |
| CM-011 | Category management is PIN-gated | High | Only parents can access /categories route |
| CM-012 | Custom category color and icon editable | Medium | Tap category to edit (custom only) |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| CM-NFR-001 | Category list load time | Time from route to visible list | < 200ms |
| CM-NFR-002 | Category seed time | Time to seed 8 defaults | < 500ms |
| CM-NFR-003 | Icon picker render | Time for 24-icon grid to render | < 100ms |

### 2.3 Assumptions

- The `CategoryRepository` interface and `CategoryRepositoryImpl` are implemented per `specs/18_task_domain.md` and `specs/19_task_data_layer.md`.
- The `CreateFamily` use case from Phase 2 can be modified to call `seedDefaultCategories` after family creation.
- Material Icons are available via the Flutter framework without additional dependencies.

### 2.4 Constraints

- Default categories are identified by `isDefault = true`. They cannot be deleted but their color can be changed.
- Category names are case-insensitive unique within a family.
- When a category is deleted, existing tasks keep the category name as a string. The category is "orphaned" but the task remains functional (graceful degradation).

---

## 3. Default Categories

### 3.1 Default Category Definitions

| Name | Icon | Color (Hex) | Material Icon Name |
|------|------|------------|-------------------|
| Kitchen | Kitchen utensils | `#FFB74D` (orange-300) | `kitchen` |
| Bathroom | Bath/shower | `#4FC3F7` (lightBlue-300) | `bathroom` |
| Bedroom | Bed | `#CE93D8` (purple-200) | `bed` |
| Living Room | Couch | `#A5D6A7` (green-200) | `weekend` |
| Yard | Garden | `#81C784` (green-300) | `yard` |
| Laundry | Washing machine | `#90CAF9` (blue-200) | `local_laundry_service` |
| Pets | Paw print | `#FFAB91` (deepOrange-200) | `pets` |
| General | House | `#B0BEC5` (blueGrey-200) | `home` |

### 3.2 Seeding Integration

```dart
// Integration point: CreateFamily use case (Phase 2)
//
// After family document is created in Drift:
// 1. Create family -> Drift insert
// 2. Create parent member -> Drift insert
// 3. Seed default categories -> CategoryRepository.seedDefaultCategories(familyId)
// 4. Enqueue sync operations for all
//
// The seedDefaultCategories method (defined in specs/19_task_data_layer.md):
// - Creates 8 categories with isDefault=true
// - Idempotent: skips categories that already exist (by name)
// - Each category gets a UUID and syncStatus=pending
//
// Cross-phase dependency note:
// This requires modifying the CreateFamily use case from Phase 2.
// The modification is additive (no breaking changes):
//   CreateFamily constructor gains CategoryRepository dependency.
//   After family creation, calls categoryRepository.seedDefaultCategories(familyId).
```

---

## 4. CategoryManagementCubit

### 4.1 States

```dart
// lib/features/tasks/presentation/cubit/category_management_cubit.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/category.dart';
import '../../domain/failures/task_failures.dart';

/// States for the category management screen.
sealed class CategoryManagementState extends Equatable {
  const CategoryManagementState();

  @override
  List<Object?> get props => [];
}

/// Loading categories from repository.
final class CategoryManagementLoading extends CategoryManagementState {
  const CategoryManagementLoading();
}

/// Categories loaded successfully.
final class CategoryManagementLoaded extends CategoryManagementState {
  const CategoryManagementLoaded({
    required this.categories,
    this.deleteError,
  });

  final List<Category> categories;
  final TaskFailure? deleteError;

  @override
  List<Object?> get props => [categories, deleteError];
}

/// Error loading categories.
final class CategoryManagementError extends CategoryManagementState {
  const CategoryManagementError(this.failure);

  final TaskFailure failure;

  @override
  List<Object?> get props => [failure];
}
```

### 4.2 Cubit Implementation

```dart
// lib/features/tasks/presentation/cubit/category_management_cubit.dart (implementation)
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/category.dart';
import '../../domain/failures/task_failures.dart';
import '../../domain/params/create_category_params.dart';
import '../../domain/params/update_category_params.dart';
import '../../domain/use_cases/create_category.dart';
import '../../domain/use_cases/delete_category.dart';
import '../../domain/use_cases/update_category.dart';
import '../../domain/use_cases/watch_categories.dart';

@injectable
class CategoryManagementCubit extends Cubit<CategoryManagementState> {
  CategoryManagementCubit(
    this._watchCategories,
    this._createCategory,
    this._updateCategory,
    this._deleteCategory,
    this._categoryRepository,
  ) : super(const CategoryManagementLoading());

  final WatchCategories _watchCategories;
  final CreateCategory _createCategory;
  final UpdateCategory _updateCategory;
  final DeleteCategory _deleteCategory;
  final CategoryRepository _categoryRepository;

  StreamSubscription<List<Category>>? _subscription;

  /// Start watching categories for the given family.
  void loadCategories(String familyId) {
    emit(const CategoryManagementLoading());
    _subscription?.cancel();
    _subscription = _watchCategories(familyId).listen(
      (categories) => emit(CategoryManagementLoaded(categories: categories)),
      onError: (error) => emit(
        const CategoryManagementError(TaskUnknownFailure()),
      ),
    );
  }

  /// Creates a new custom category.
  Future<void> createCategory({
    required String name,
    required String icon,
    required String color,
    required String familyId,
  }) async {
    final result = await _createCategory(CreateCategoryParams(
      name: name,
      icon: icon,
      color: color,
      familyId: familyId,
    ));

    result.when(
      success: (_) {
        // Stream will automatically emit updated list
      },
      failure: (failure) {
        if (state is CategoryManagementLoaded) {
          final current = state as CategoryManagementLoaded;
          emit(CategoryManagementLoaded(
            categories: current.categories,
            deleteError: failure as TaskFailure,
          ));
        }
      },
    );
  }

  /// Updates a category's name, icon, or color.
  Future<void> updateCategory({
    required String categoryId,
    String? name,
    String? icon,
    String? color,
  }) async {
    await _updateCategory(UpdateCategoryParams(
      categoryId: categoryId,
      name: name,
      icon: icon,
      color: color,
    ));
    // Stream handles UI update
  }

  /// Deletes a custom category.
  /// Returns error if it's a default or has active tasks.
  Future<void> deleteCategory(String categoryId) async {
    final result = await _deleteCategory(categoryId);

    result.when(
      success: (_) {
        // Stream will automatically emit updated list
      },
      failure: (failure) {
        if (state is CategoryManagementLoaded) {
          final current = state as CategoryManagementLoaded;
          emit(CategoryManagementLoaded(
            categories: current.categories,
            deleteError: failure as TaskFailure,
          ));
        }
      },
    );
  }

  /// Clears any delete error (after user dismisses snackbar).
  void clearError() {
    if (state is CategoryManagementLoaded) {
      final current = state as CategoryManagementLoaded;
      emit(CategoryManagementLoaded(categories: current.categories));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

---

## 5. CategoryManagementScreen

### 5.1 Screen Layout

```dart
// lib/features/tasks/presentation/screens/category_management_screen.dart
//
// Route: /categories (PIN-gated)
//
// AppBar:
//   - Title: "Categories" (Nunito, 20sp)
//   - Back arrow leading
//   - No actions
//
// Body:
//   - BlocBuilder<CategoryManagementCubit, CategoryManagementState>
//
//   Loading state:
//     - Center CircularProgressIndicator
//
//   Loaded state:
//     - ListView of category items
//     - Section header: "Default Categories" (8 items)
//     - Section header: "Custom Categories" (0+ items)
//     - Each item: CategoryListTile widget
//
//   Error state:
//     - Error icon + message + "Retry" button
//
// FAB:
//   - "+" icon, extended: "New Category"
//   - Navigates to /categories/new
//   - On return: stream auto-updates list
//
// BlocListener:
//   - CategoryManagementLoaded with deleteError:
//     Show SnackBar with error message
//     "Default categories cannot be deleted" for DefaultCategoryFailure
//     "Category is used by X tasks" for CategoryInUseFailure
```

### 5.2 CategoryListTile Widget

```dart
// lib/features/tasks/presentation/widgets/category_list_tile.dart
//
// ListTile with:
//   - Leading: Circle (40dp) filled with category color, containing icon
//     - Icon: Material icon by name, white, 24dp
//   - Title: Category name (Nunito 16sp)
//   - Subtitle: "Default" badge for default categories
//   - Trailing: none for default, chevron for custom (tap to edit)
//
// For custom categories:
//   - Dismissible widget wrapping the ListTile
//   - Swipe direction: endToStart (right to left)
//   - Background: red with trash icon
//   - confirmDismiss: shows confirmation dialog
//   - onDismissed: calls cubit.deleteCategory(id)
//
// For default categories:
//   - NOT Dismissible
//   - Long-press shows "Default categories cannot be deleted" tooltip
//   - Tap opens edit dialog (color-only edit for defaults)
//
// Dimensions:
//   - Tile height: 64dp
//   - Icon circle: 40dp diameter
//   - Padding: 16dp horizontal
```

### 5.3 Delete Confirmation Dialog

```dart
// Delete confirmation for custom categories:
//
// AlertDialog:
//   Title: "Delete Category?"
//   Content:
//     - "Delete '{name}' category?"
//     - If tasks reference it: "X active tasks use this category.
//       Tasks will keep the category label but it won't appear
//       in the picker anymore."
//   Actions:
//     - "Cancel" text button
//     - "Delete" red text button
//
// The active task count is fetched via
// CategoryRepository.countActiveTasksForCategory(categoryId).
//
// If count > 0, the dialog warns but still allows deletion
// (the user confirmed). The repository's CategoryInUseFailure
// is only returned if the implementation enforces a hard block.
//
// Decision: Show warning but allow deletion with confirmation.
// Update: Per the prompt, "show error" means block deletion if
// tasks reference it. Changed to: deletion IS blocked if active
// tasks reference it. User must reassign or complete those tasks first.
```

---

## 6. CategoryCreateScreen

### 6.1 Screen Layout

```dart
// lib/features/tasks/presentation/screens/category_create_screen.dart
//
// Route: /categories/new (PIN-gated)
//
// AppBar:
//   - Title: "New Category"
//   - Leading: X close button
//   - Actions: checkmark save button
//
// Body (SingleChildScrollView):
//
// Section 1: Name
//   - TextFormField: "Category name"
//   - Hint: "e.g., Garden Shed"
//   - Max length: 30 (with counter)
//   - Validation: 2-30 chars, unique in family (checked on submit)
//
// Section 2: Icon
//   - Label: "Choose an icon"
//   - Grid of 24 Material Icons (4 columns, 6 rows)
//   - Selected icon: primary container background, primary color
//   - Unselected: grey-200 background, grey-600 color
//   - Icons sized: 32dp, grid cell: 64dp
//   - Tap selects icon
//
// Section 3: Color
//   - Label: "Choose a color"
//   - Grid of 12 color circles (6 columns, 2 rows)
//   - Selected: thick border (3dp) + checkmark overlay
//   - Unselected: thin border (1dp)
//   - Circle size: 48dp, grid cell: 56dp
//
// Section 4: Preview
//   - "Preview" label
//   - Shows the CategoryListTile with selected name, icon, color
//   - Updates live as user changes selections
//
// Submit:
//   - Checkmark button calls cubit.createCategory(...)
//   - On success: pops back to CategoryManagementScreen
//   - On failure: shows error SnackBar (e.g., duplicate name)
```

### 6.2 Icon Grid

```dart
// Available icons for category picker
// 24 household-relevant Material Icons
//
// Row 1: kitchen, bathroom, bed, weekend (couch), yard, home
// Row 2: local_laundry_service, pets, cleaning_services, restaurant, garage, eco
// Row 3: child_care, sports_esports, fitness_center, school, work, shopping_cart
// Row 4: directions_car, build, electrical_services, plumbing, recycling, star
//
// Icon names (string identifiers used in Category.icon field):
const List<String> kCategoryIcons = [
  'kitchen',
  'bathroom',
  'bed',
  'weekend',
  'yard',
  'home',
  'local_laundry_service',
  'pets',
  'cleaning_services',
  'restaurant',
  'garage',
  'eco',
  'child_care',
  'sports_esports',
  'fitness_center',
  'school',
  'work',
  'shopping_cart',
  'directions_car',
  'build',
  'electrical_services',
  'plumbing',
  'recycling',
  'star',
];
```

### 6.3 Color Grid

```dart
// Available colors for category picker
// 12 pastel colors from the design system
//
const List<String> kCategoryColors = [
  '#FFB74D', // orange-300
  '#FF8A65', // deepOrange-300
  '#F06292', // pink-300
  '#CE93D8', // purple-200
  '#9575CD', // deepPurple-300
  '#7986CB', // indigo-300
  '#4FC3F7', // lightBlue-300
  '#4DD0E1', // cyan-300
  '#81C784', // green-300
  '#A5D6A7', // green-200
  '#90CAF9', // blue-200
  '#B0BEC5', // blueGrey-200
];
```

---

## 7. Category Picker Widget (for Task Creation)

### 7.1 CategoryPicker Widget

```dart
// lib/features/tasks/presentation/widgets/category_picker.dart
//
// A horizontal scrolling row of category ChoiceChips
// used in the TaskCreationScreen (spec 21, Section 4.2).
//
// Props:
//   - categories: List<Category>
//   - selectedCategory: String? (category name)
//   - onSelected: (String categoryName) -> void
//   - onCreateNew: () -> void
//
// Layout:
//   - SingleChildScrollView horizontal
//   - Chips: category icon (14dp) + name text
//   - Selected chip: filled with category color, white text
//   - Unselected chip: outlined with category color
//   - Last chip: "+ New" with dashed border, grey
//
// Chip dimensions:
//   - Height: 36dp
//   - Padding: 12dp horizontal
//   - Icon-text spacing: 6dp
//   - Border radius: 18dp (pill shape)
//   - Between chips: 8dp spacing
//
// Behavior:
//   - Single-select (only one category at a time)
//   - Tapping selected chip deselects it (no category = validation error)
//   - Tapping "+ New" calls onCreateNew -> navigates to /categories/new
//   - When returning from create screen, new category auto-selected
```

### 7.2 Icon Resolver

```dart
// lib/features/tasks/presentation/utils/icon_resolver.dart
//
// Utility to convert category icon name strings to Material IconData.
//
// The Category entity stores icon names as strings (e.g., "kitchen").
// This resolver maps them to Flutter IconData for rendering.
//
// static IconData resolve(String iconName) {
//   return _iconMap[iconName] ?? Icons.category;
// }
//
// static const _iconMap = {
//   'kitchen': Icons.kitchen,
//   'bathroom': Icons.bathroom,
//   'bed': Icons.bed,
//   'weekend': Icons.weekend,
//   'yard': Icons.yard,
//   'home': Icons.home,
//   'local_laundry_service': Icons.local_laundry_service,
//   'pets': Icons.pets,
//   'cleaning_services': Icons.cleaning_services,
//   'restaurant': Icons.restaurant,
//   'garage': Icons.garage,
//   'eco': Icons.eco,
//   'child_care': Icons.child_care,
//   'sports_esports': Icons.sports_esports,
//   'fitness_center': Icons.fitness_center,
//   'school': Icons.school,
//   'work': Icons.work,
//   'shopping_cart': Icons.shopping_cart,
//   'directions_car': Icons.directions_car,
//   'build': Icons.build,
//   'electrical_services': Icons.electrical_services,
//   'plumbing': Icons.plumbing,
//   'recycling': Icons.recycling,
//   'star': Icons.star,
// };
```

---

## 8. File Structure

### 8.1 Category-Related Files

```
lib/features/tasks/
  domain/
    constants/
      default_categories.dart          # kDefaultCategories list
    entities/
      category.dart                    # Category entity (freezed)
    params/
      create_category_params.dart      # CreateCategoryParams
      update_category_params.dart      # UpdateCategoryParams
    repositories/
      category_repository.dart         # Abstract interface
    use_cases/
      watch_categories.dart
      create_category.dart
      update_category.dart
      delete_category.dart
  data/
    datasources/
      category_local_datasource.dart   # Drift DAO
      category_remote_datasource.dart  # Firestore
    mappers/
      category_mapper.dart             # Data conversion
    repositories/
      category_repository_impl.dart    # Concrete implementation
  presentation/
    cubit/
      category_management_cubit.dart   # Screen state management
    screens/
      category_management_screen.dart  # List screen
      category_create_screen.dart      # Create/edit screen
    widgets/
      category_list_tile.dart          # List item widget
      category_picker.dart             # Chip row for task form
    utils/
      icon_resolver.dart               # String -> IconData mapping
    constants/
      category_icons.dart              # kCategoryIcons list
      category_colors.dart             # kCategoryColors list
```

---

## 9. Impact Analysis

### 9.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/` (category files) | New | Low | New files, no existing modifications |
| `CreateFamily` use case (Phase 2) | Modified | Medium | Add CategoryRepository dependency and seedDefaultCategories call |
| `lib/app/di/injection.dart` | Modified | Low | CategoryRepository registered (auto via injectable) |

### 9.2 Dependencies

- **Upstream:** `specs/18_task_domain.md` (Category entity, CategoryRepository), `specs/19_task_data_layer.md` (CategoryRepositoryImpl), `specs/10_family_onboarding.md` (CreateFamily use case for seeding)
- **Downstream:** `specs/21_task_creation_screen.md` (CategoryPicker in task form), `specs/20_task_list_screen.md` (category color strip on TaskCard)

### 9.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Default category seeding fails silently | Low | Medium | Verify seed on family load; retry if < 8 defaults found |
| Icon name string mismatch between platforms | Low | Low | Unit test icon resolver covers all 24 icons |
| Category color not parseable | Low | Low | Default to grey if hex parse fails |
| Orphaned category reference after deletion | Medium | Low | Graceful degradation: task shows category name string, grey color strip |
| Modifying CreateFamily breaks Phase 2 tests | Low | Medium | Additive change only; mock CategoryRepository in existing tests |

---

## 10. Functional Tests

### 10.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| CM-T001 | Seed creates 8 defaults | Empty family | seedDefaultCategories | 8 categories with isDefault=true | High |
| CM-T002 | Seed is idempotent | Family with 8 defaults | seedDefaultCategories | No duplicates, still 8 | High |
| CM-T003 | Create custom category | Valid params | createCategory | Category in stream, isDefault=false | High |
| CM-T004 | Create duplicate name blocked | "Kitchen" exists | createCategory("Kitchen") | ValidationFailure returned | High |
| CM-T005 | Delete default blocked | Default category | deleteCategory | DefaultCategoryFailure | High |
| CM-T006 | Delete custom succeeds | Custom, no tasks | deleteCategory | Category removed from stream | High |
| CM-T007 | Delete with tasks blocked | 3 tasks reference category | deleteCategory | CategoryInUseFailure(3) | High |
| CM-T008 | Categories stream updates on create | 8 defaults | createCategory | Stream emits 9 categories | Medium |

### 10.2 Widget Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| CM-W001 | List renders all categories | 8 defaults + 2 custom | Render | 10 items visible | High |
| CM-W002 | Swipe-to-delete custom | Custom category tile | Swipe left | Delete confirmation shown | High |
| CM-W003 | Swipe blocked for default | Default category tile | Swipe left | No dismissible behavior | High |
| CM-W004 | Icon grid renders 24 icons | Create screen | Render | 24 icon cells visible | Medium |
| CM-W005 | Color grid renders 12 colors | Create screen | Render | 12 color circles visible | Medium |
| CM-W006 | Preview updates live | Name="Garage", icon="garage", color="#81C784" | Change fields | Preview tile shows Garage with icon and color | Medium |
| CM-W007 | CategoryPicker renders chips | 8 categories | Render picker | 8 chips + "New" chip | High |
| CM-W008 | CategoryPicker "New" chip navigates | Tap "New" | Tap | Navigation to /categories/new triggered | Medium |

---

## 11. Implementation Recommendations

### 11.1 Prototype Checklist

1. **What can a user do?** "As Marcus, I can open Categories from the task creation form, see Kitchen/Bathroom/etc., create a new 'Garden Shed' category with a green color and plant icon, and use it when creating a new chore."
2. **Which screens are delivered?** CategoryManagementScreen (`/categories`), CategoryCreateScreen (`/categories/new`).
3. **What is the minimum data flow?** Parent taps "+ New Category" -> enters name/icon/color -> save -> CategoryRepositoryImpl creates in Drift with syncStatus=pending -> stream update -> category appears in list and in task form picker.
4. **What is the offline behavior?** Category CRUD is fully offline. Categories are local-first, synced via SyncEngine.
5. **What does "done" look like?** Open Categories screen -> see 8 default categories -> create "Garden Shed" with plant icon -> go to task creation -> see "Garden Shed" in category picker -> select it -> save task.

### 11.2 Suggested Approach

1. Implement default category constants and icon/color constants.
2. Implement IconResolver utility.
3. Implement CategoryManagementCubit.
4. Build CategoryListTile with Dismissible (custom categories) and non-dismissible (defaults).
5. Build CategoryManagementScreen with section headers.
6. Build CategoryCreateScreen with icon grid, color grid, preview.
7. Build CategoryPicker widget for task form integration.
8. Integrate seedDefaultCategories into CreateFamily use case.
9. Write unit tests (8 tests).
10. Write widget tests (8 tests).

### 11.3 Estimated Effort

**S (1-2 days)** -- Category management is the simplest feature in Phase 3. The domain and data layers are already defined in specs 18 and 19. The UI is straightforward -- a list screen and a simple create form.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
