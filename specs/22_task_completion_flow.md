# Task Completion Flow

## 1. Overview

### 1.1 Summary

This specification defines the task completion flow -- the celebration moment when a family member finishes a chore. It covers the four completion trigger paths, the `TaskCompletionCubit` state machine, the completion animation sequence (checkbox bounce, points flash, Lottie confetti), the photo proof capture flow, the parent verification flow, and the "complete on behalf of" flow. The completion moment is designed to be the most emotionally rewarding interaction in the app -- it must feel satisfying, fast, and celebratory.

### 1.2 Business Context

The completion flow is the core reward loop that drives behavior change. Alex (age 10) should feel a surge of accomplishment when they check off a chore. The confetti animation and points flash create a micro-dopamine hit that reinforces the habit. For Marcus and Sofia, verifying completed tasks gives them visibility into who did what. The photo proof feature adds accountability for chores that need visual confirmation (e.g., "Is the room actually clean?").

### 1.3 Scope

**In scope:**
- Four completion trigger paths (checkbox, detail button, subtask auto-complete, on-behalf-of)
- `TaskCompletionCubit` with complete state machine
- Completion animation sequence (350ms micro-animations + 2000ms confetti)
- `PointsFlashWidget` animated text
- Photo proof capture and preview flow
- Parent verification flow
- "Complete on behalf of" member picker
- Haptic feedback patterns
- Emma (toddler) special celebration handling
- Offline completion behavior

**Out of scope:**
- Task list screen (see `specs/20_task_list_screen.md`)
- Notification of completion to other family members (Phase 7)
- Points accumulation and spending (Phase 4)

### 1.4 References

- `specs/17_phase3_foundations.md` -- Lottie assets, flutter_animate dependency, route `/tasks/:taskId/complete`
- `specs/18_task_domain.md` -- CompleteTask use case, CompleteTaskParams, TaskCompletedEvent
- `specs/19_task_data_layer.md` -- TaskRepositoryImpl.completeTask, point award logic
- `CLAUDE.md` -- Emma gets 2500ms celebrations, auto-approved rewards, photo compression settings

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| TCF-001 | Quick-complete from TaskCard checkbox | High | Single tap completes task, triggers animation |
| TCF-002 | Complete from TaskDetailScreen button | High | "Mark Complete" button triggers full completion flow |
| TCF-003 | Auto-prompt when all subtasks checked | Medium | Checking last subtask shows "Mark task complete?" dialog |
| TCF-004 | "Complete on behalf of" for parents | High | Parent can select which member completed the task |
| TCF-005 | Completion animation plays on success | High | Checkbox bounce + points flash + confetti in sequence |
| TCF-006 | Points awarded to completing member | High | Member's point total increases by task.points |
| TCF-007 | Photo proof required before completion | High | Tasks with photoProofRequired block completion until photo attached |
| TCF-008 | Photo proof captured via camera | High | Camera capture via image_picker, preview, then submit |
| TCF-009 | Parent verification changes status | High | Completed -> Verified status transition |
| TCF-010 | Verification does not award extra points | Medium | Points only on initial completion |
| TCF-011 | Emma gets extended celebration | Medium | 2500ms confetti + heavy haptic for toddler age group |
| TCF-012 | Completion works offline | High | Local Drift update, points awarded locally, sync queued |
| TCF-013 | Haptic feedback on completion | Medium | Medium impact on checkbox, heavy impact for Emma |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| TCF-NFR-001 | Time from tap to animation start | Perceived latency | < 100ms |
| TCF-NFR-002 | Animation frame rate | Smooth animation | 60 FPS throughout |
| TCF-NFR-003 | Photo capture to preview | Camera launch to preview display | < 3 seconds |
| TCF-NFR-004 | Photo compression time | Full-res to compressed | < 2 seconds |
| TCF-NFR-005 | Confetti animation memory | Peak memory during animation | < 5 MB additional |

### 2.3 Assumptions

- The `flutter_animate` package is installed and provides `scale`, `fade`, and `slideY` effects.
- The Lottie animation file `task_complete.json` is in `assets/animations/`.
- The `image_picker` package supports camera capture on both iOS and Android.
- The `CompleteTask` use case validates task state and awards points via repository.
- `HapticFeedback` is available from `flutter/services.dart`.

### 2.4 Constraints

- Animations must not block the UI thread -- Lottie runs on a separate render layer.
- Photo proof files must be compressed before storage (max 800px, JPEG 85%).
- The completion flow must be responsive even offline -- the celebration plays immediately, sync happens in background.
- Camera permission must be requested before first use (handled by `image_picker`).

---

## 3. Completion Trigger Paths

### 3.1 Path 1: Quick-Complete from TaskCard Checkbox

```
User taps checkbox on TaskCard
  -> HapticFeedback.mediumImpact()
  -> TaskListBloc receives TaskCompletionToggled event
  -> CompleteTask use case called
  -> On success:
     -> Checkbox animates (scale bounce)
     -> PointsFlashWidget plays "+{N} pts"
     -> If not photo-proof-required: completion done
     -> Task moves to completed group in list
  -> On failure:
     -> Checkbox reverts to unchecked
     -> SnackBar shows error
```

**Notes:**
- This is the fastest path -- no navigation, no modal.
- Confetti does NOT play for quick-complete (too disruptive in list view).
- Points flash plays inline on the TaskCard.

### 3.2 Path 2: Complete from TaskDetailScreen

```
User taps "Mark Complete" button on TaskDetailScreen
  -> Navigate to /tasks/:taskId/complete (modal route)
  -> TaskCompletionCubit.completeRequested(taskId, memberId)
  -> If photoProofRequired:
     -> State: CompletionRequiresPhoto
     -> User captures photo
     -> TaskCompletionCubit.photoAttached(file)
  -> TaskCompletionCubit.confirmCompletion()
  -> CompleteTask use case called
  -> On success:
     -> State: CompletionSuccess
     -> Full celebration animation sequence
     -> After animation: pop back to TaskDetailScreen (updated)
  -> On failure:
     -> State: CompletionFailure
     -> Error message shown
     -> "Try Again" button
```

### 3.3 Path 3: Auto-Prompt from Subtask Checklist

```
User checks the last uncompleted subtask on TaskDetailScreen
  -> TaskDetailCubit detects all subtasks completed
  -> Show dialog: "All checklist items done! Mark task as complete?"
     -> "Not Yet" dismisses dialog
     -> "Complete" triggers Path 2 (navigates to completion screen)
```

### 3.4 Path 4: Complete on Behalf Of

```
Parent taps "Complete on behalf of" on TaskDetailScreen
  -> Show member picker bottom sheet
  -> Parent selects which member completed the task
  -> Navigate to /tasks/:taskId/complete with selectedMemberId
  -> Same flow as Path 2, but completedByMemberId = selected member
  -> Points awarded to selected member, not the parent
```

---

## 4. TaskCompletionCubit

### 4.1 States

```dart
// lib/features/tasks/presentation/cubit/task_completion_cubit.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';
import '../../domain/failures/task_failures.dart';

/// States for the task completion flow.
sealed class TaskCompletionState extends Equatable {
  const TaskCompletionState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state.
final class CompletionIdle extends TaskCompletionState {
  const CompletionIdle();
}

/// Completion in progress (calling use case).
final class CompletionInProgress extends TaskCompletionState {
  const CompletionInProgress();
}

/// Photo proof is required before completion can proceed.
final class CompletionRequiresPhoto extends TaskCompletionState {
  const CompletionRequiresPhoto({required this.task});

  final Task task;

  @override
  List<Object?> get props => [task];
}

/// Photo has been captured, ready to submit.
final class CompletionPhotoReady extends TaskCompletionState {
  const CompletionPhotoReady({
    required this.task,
    required this.photoPath,
  });

  final Task task;
  final String photoPath;

  @override
  List<Object?> get props => [task, photoPath];
}

/// Task completed successfully. Triggers celebration animation.
final class CompletionSuccess extends TaskCompletionState {
  const CompletionSuccess({
    required this.task,
    required this.pointsAwarded,
    required this.isEmma,
  });

  final Task task;
  final int pointsAwarded;
  final bool isEmma; // For extended celebration

  @override
  List<Object?> get props => [task, pointsAwarded, isEmma];
}

/// Completion failed.
final class CompletionFailure extends TaskCompletionState {
  const CompletionFailure(this.failure);

  final TaskFailure failure;

  @override
  List<Object?> get props => [failure];
}
```

### 4.2 Cubit Implementation

```dart
// lib/features/tasks/presentation/cubit/task_completion_cubit.dart (implementation)
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/enums/age_group.dart';
import '../../domain/params/complete_task_params.dart';
import '../../domain/use_cases/complete_task.dart';

@injectable
class TaskCompletionCubit extends Cubit<TaskCompletionState> {
  TaskCompletionCubit(
    this._completeTask,
    this._taskRepository,
  ) : super(const CompletionIdle());

  final CompleteTask _completeTask;
  final TaskRepository _taskRepository;

  String _taskId = '';
  String _memberId = '';
  String? _photoPath;
  Task? _task;

  /// Initiates the completion flow for a task.
  Future<void> completeRequested(String taskId, String memberId) async {
    _taskId = taskId;
    _memberId = memberId;

    // Load the task to check photo requirement
    final result = await _taskRepository.getTask(taskId);
    result.when(
      success: (task) {
        _task = task;
        if (task.photoProofRequired) {
          emit(CompletionRequiresPhoto(task: task));
        } else {
          _doComplete();
        }
      },
      failure: (failure) => emit(CompletionFailure(failure as TaskFailure)),
    );
  }

  /// Attaches a captured photo to the completion.
  void photoAttached(XFile file) {
    _photoPath = file.path;
    if (_task != null) {
      emit(CompletionPhotoReady(task: _task!, photoPath: file.path));
    }
  }

  /// Confirms completion (after photo if required).
  Future<void> confirmCompletion() async {
    await _doComplete();
  }

  /// Cancels the completion flow.
  void cancelCompletion() {
    _photoPath = null;
    _task = null;
    emit(const CompletionIdle());
  }

  Future<void> _doComplete() async {
    emit(const CompletionInProgress());

    final result = await _completeTask(CompleteTaskParams(
      taskId: _taskId,
      completedByMemberId: _memberId,
      photoUrl: _photoPath,
    ));

    result.when(
      success: (task) {
        final isEmma = task.ageGroup == AgeGroup.toddler;
        emit(CompletionSuccess(
          task: task,
          pointsAwarded: task.points,
          isEmma: isEmma,
        ));
      },
      failure: (failure) => emit(CompletionFailure(failure as TaskFailure)),
    );
  }
}
```

---

## 5. Completion Animation Sequence

### 5.1 Standard Completion (from TaskDetailScreen)

```
Time 0ms:     CompletionSuccess state emitted
Time 0-150ms: Checkbox fills with checkmark (scale 0.8 -> 1.2 -> 1.0)
              - flutter_animate: .scale(begin: 0.8, end: 1.0)
              - Color: transparent -> green-500
              - Curve: Curves.elasticOut
Time 50-250ms: Points flash animates
              - "+{N} pts" text appears
              - Color: amber-700, Nunito 18sp bold
              - Slide up 40px (slideY: 0 -> -40)
              - Fade out at 250ms
              - flutter_animate: .slideY(begin: 0, end: -0.5)
                                 .fadeOut(delay: 150ms)
Time 150-2150ms: Lottie confetti overlay
              - Full-screen overlay (Stack, positioned fill)
              - Plays once (repeat: false)
              - Auto-dismiss after animation completes
              - Duration: 2000ms (asset-defined)
              - Lottie.asset('assets/animations/task_complete.json')
Time 2150ms:  Animation complete
              - Pop completion screen
              - Return to TaskDetailScreen with updated task state
```

### 5.2 Quick-Complete (from TaskCard checkbox)

```
Time 0ms:     TaskCompletionToggled event processed
              HapticFeedback.mediumImpact()
Time 0-150ms: Checkbox bounces (scale effect)
              - Same as standard but inline on the TaskCard
Time 50-250ms: PointsFlashWidget plays on the TaskCard
              - Positioned above the checkbox, floating overlay
              - Same animation as standard
Time 250ms:   Animation complete
              - No confetti (too disruptive in list view)
              - TaskCard background transitions to green-50
              - Task filters out of "Pending" view on next stream update
```

### 5.3 Emma Special Celebration

```
Time 0ms:     CompletionSuccess with isEmma = true
              HapticFeedback.heavyImpact()
Time 0-150ms: Checkbox fills (same as standard)
Time 50-350ms: Points flash (extended: 300ms, larger text 24sp)
Time 150-2650ms: Extended confetti (2500ms, per CLAUDE.md)
              - Same Lottie asset but with repeat: true for 2.5s
              - OR a separate toddler-specific animation asset
Time 0-2500ms: Device vibration pattern (3 short pulses)
              HapticFeedback.heavyImpact() at 0ms, 800ms, 1600ms
Time 2650ms:  Animation complete, pop back
```

---

## 6. PointsFlashWidget

### 6.1 Widget Specification

```dart
// lib/features/tasks/presentation/widgets/points_flash_widget.dart
//
// An animated widget that shows "+{N} pts" floating upward and fading out.
//
// Used in:
// 1. TaskCompletionScreen (full celebration)
// 2. TaskCard (quick-complete inline flash)
// 3. TaskDetailScreen (post-completion display)
//
// Constructor params:
//   - pointsAwarded: int (required)
//   - onComplete: VoidCallback? (called when animation finishes)
//   - style: PointsFlashStyle (normal or large -- for Emma)
//
// Animation (using flutter_animate):
//   Text("+${pointsAwarded} pts")
//     .animate(onPlay: (c) => c.forward())
//     .fadeIn(duration: 100.ms)
//     .scale(begin: 0.5, end: 1.0, duration: 150.ms, curve: Curves.elasticOut)
//     .slideY(begin: 0, end: -0.5, duration: 250.ms, curve: Curves.easeOut)
//     .fadeOut(delay: 150.ms, duration: 100.ms)
//
// Styling:
//   Normal:
//     Text: Nunito 18sp bold, amber-700
//     Total duration: 350ms
//
//   Large (Emma):
//     Text: Nunito 24sp bold, amber-600
//     Total duration: 500ms
//     Includes star emoji prefix: "⭐ +{N} pts"
//
// Positioning:
//   In TaskCard: Overlay, positioned above checkbox, right-aligned
//   In CompletionScreen: Center of screen, above confetti layer
```

---

## 7. Photo Proof Flow

### 7.1 Flow Diagram

```
CompletionRequiresPhoto state
  |
  v
Photo Proof Screen:
  - "Take a photo to complete this chore" message
  - Camera preview placeholder (greyed rectangle with camera icon)
  - "Take Photo" primary button
  - "Cancel" text button
  |
  v (tap "Take Photo")
ImagePicker.pickImage(source: ImageSource.camera)
  |
  v (photo captured)
Photo Preview Screen:
  - Full-width image preview (BoxFit.cover, max height 400dp)
  - "Retake" outlined button
  - "Submit" primary button
  |
  v (tap "Submit")
Photo compression:
  - Resize to max 800px longest edge
  - JPEG quality 85%
  - Save to temp directory
  |
  v
TaskCompletionCubit.photoAttached(compressedFile)
  -> State: CompletionPhotoReady
  -> Auto-proceed to confirmCompletion()
  |
  v
Completion flow continues (points, animation, sync)
```

### 7.2 Photo Compression

```dart
// Photo compression utility
// lib/features/tasks/data/utils/photo_compressor.dart
//
// Uses image package or platform-specific compression.
//
// Input: XFile from image_picker (full resolution)
// Output: File at temp path, compressed
//
// Settings:
//   maxWidth: 800
//   maxHeight: 800
//   quality: 85 (JPEG)
//   format: JPEG
//
// Implementation note:
//   image_picker supports maxWidth/maxHeight params directly:
//   ImagePicker().pickImage(
//     source: ImageSource.camera,
//     maxWidth: 800,
//     maxHeight: 800,
//     imageQuality: 85,
//   )
//   This avoids needing a separate compression step.
```

### 7.3 Photo Storage Strategy

```
Phase 3 behavior:
  - Photo saved to local temp directory after compression
  - Photo path stored in Task.photoUrl field (local path)
  - SyncEngine enqueues photo upload as a separate SyncOperation
  - On sync: photo uploaded to Firebase Storage at:
    families/{familyId}/task_proofs/{taskId}/{memberId}_{timestamp}.jpg
  - After upload: Task.photoUrl updated to Firebase Storage URL
  - Old local file cleaned up after confirmed upload

Offline behavior:
  - Photo remains in temp directory
  - Task.photoUrl is a local path until synced
  - CachedNetworkImage shows local file via file:// URI
  - On reconnect: photo uploads, URL updates
```

---

## 8. Parent Verification Flow

### 8.1 Verification UX

```
TaskDetailScreen (task.status == completed):
  |
  v
Bottom action bar shows "Verify" primary button
  - Button text: "Verify Completion"
  - Button style: elevated, green color
  - Only visible to parent profiles
  |
  v (tap "Verify")
Confirmation dialog:
  - Title: "Verify Task?"
  - Content: "Confirm that '{task.title}' was completed satisfactorily."
  - If photo proof exists: show photo thumbnail in dialog
  - Actions: "Cancel" / "Verify"
  |
  v (tap "Verify")
VerifyTask use case called
  |
  v (success)
  - Task status: completed -> verified
  - Subtle checkmark animation (task_verified.json Lottie, 800ms)
  - "Task verified" SnackBar
  - TaskDetailScreen refreshes with verified status badge
  |
  v (failure)
  - Error SnackBar with failure message
```

### 8.2 Verification in Task List

```dart
// In the TaskListScreen, verified tasks are visually distinct:
//
// TaskCard for verified tasks:
//   - Background: TaskColors.verifiedBackground (orange-50)
//   - Status badge: "Verified" with checkmark icon, green
//   - Title: no strikethrough (unlike completed, which has strikethrough)
//   - Verified icon overlay on task category strip
//
// Filter behavior:
//   - "Completed" filter includes both completed AND verified tasks
//   - No separate "Verified" filter (keeps UI simple)
```

---

## 9. Complete on Behalf Of

### 9.1 Flow

```dart
// lib/features/tasks/presentation/widgets/complete_on_behalf_dialog.dart
//
// Modal bottom sheet showing family members.
//
// Header: "Who completed this chore?"
// Body:
//   - List of assignee members (primary options)
//   - Divider
//   - "Other family member" section with remaining members
//   - Each item: avatar (40dp) + name + role badge
//   - Single-select radio behavior
//
// Footer:
//   - "Cancel" text button
//   - "Continue" primary button (enabled when member selected)
//
// On submit:
//   - Navigate to completion flow with selectedMemberId
//   - Points awarded to selected member
//   - Completion attributed to selected member in audit log
//   - Active profile (parent) recorded as the submitter
//
// When completing on behalf of Emma:
//   - Emma gets the extended celebration (2500ms, heavy haptic)
//   - "⭐ +{N} pts for Emma!" message
//
// When completing on behalf of Alex:
//   - Standard celebration
//   - "+{N} pts for Alex!" personalized message
```

---

## 10. TaskCompletionScreen

### 10.1 Screen Layout

```dart
// lib/features/tasks/presentation/screens/task_completion_screen.dart
//
// This is a modal fullscreen route presented as a dialog.
// It overlays the TaskDetailScreen or TaskListScreen.
//
// Background: semi-transparent black overlay (opacity 0.3)
//
// Content (centered card, 80% width):
//   CompletionIdle:
//     - "Completing..." loading indicator
//
//   CompletionInProgress:
//     - CircularProgressIndicator
//     - "Saving..." text
//
//   CompletionRequiresPhoto:
//     - Task title
//     - "This chore requires photo proof"
//     - Camera icon (64dp, grey-400)
//     - "Take Photo" primary button
//     - "Cancel" text button
//
//   CompletionPhotoReady:
//     - Photo preview (thumbnail, 200dp height)
//     - "Retake" / "Submit" buttons
//
//   CompletionSuccess:
//     - Full-screen celebration layer (on top of everything):
//       1. Lottie confetti (positioned: fill)
//       2. PointsFlashWidget (centered)
//       3. Task title: "'{title}' completed!" (below points)
//     - Auto-dismiss after animation duration
//     - Tap anywhere to dismiss early
//
//   CompletionFailure:
//     - Error icon (64dp, red)
//     - Error message from TaskFailure
//     - "Try Again" primary button
//     - "Cancel" text button
```

---

## 11. Impact Analysis

### 11.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/presentation/cubit/task_completion_cubit.dart` | New | Low | New file |
| `lib/features/tasks/presentation/screens/task_completion_screen.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/points_flash_widget.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/complete_on_behalf_dialog.dart` | New | Low | New file |
| `assets/animations/task_complete.json` | New | Low | Lottie asset |
| `assets/animations/task_verified.json` | New | Low | Lottie asset |
| `TaskCard` (from spec 20) | Modified | Medium | Add quick-complete animation |
| `TaskDetailScreen` (from spec 20) | Modified | Medium | Add verification and on-behalf-of buttons |

### 11.2 Dependencies

- **Upstream:** `flutter_animate` (animation chains), `lottie` (confetti), `image_picker` (photo capture), `specs/18_task_domain.md` (CompleteTask, VerifyTask use cases)
- **Downstream:** `specs/25_phase3_test_plan.md` (completion flow tests)

### 11.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Lottie animation causes jank | Low | Medium | Test on low-end device; use RepaintBoundary; lazy-load animation |
| Camera permission denied | Medium | Low | Graceful fallback: "Camera permission needed" message with settings link |
| Photo too large for Firestore sync | Low | Medium | image_picker max params enforce 800px limit before storage |
| Quick-complete fires multiple times (double-tap) | Medium | Medium | Debounce checkbox taps (300ms); disable during animation |
| Emma celebration blocks parent interaction too long | Low | Low | Allow tap-to-dismiss at any time during animation |

---

## 12. Functional Tests

### 12.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TCF-T001 | Standard completion success | Actionable task, no photo required | completeRequested | CompletionSuccess with pointsAwarded | High |
| TCF-T002 | Photo required blocks completion | Task with photoProofRequired=true | completeRequested | CompletionRequiresPhoto state | High |
| TCF-T003 | Photo attached transitions state | CompletionRequiresPhoto state | photoAttached(file) | CompletionPhotoReady state | High |
| TCF-T004 | Confirm completion after photo | CompletionPhotoReady state | confirmCompletion() | CompletionSuccess | High |
| TCF-T005 | Completion failure on already completed | Task already completed | completeRequested | CompletionFailure with InvalidState | High |
| TCF-T006 | Cancel returns to idle | Any active state | cancelCompletion() | CompletionIdle | Medium |
| TCF-T007 | Emma gets isEmma flag | Task with ageGroup=toddler | completeRequested | CompletionSuccess(isEmma: true) | Medium |
| TCF-T008 | Points flash shows correct amount | Task with 25 points | CompletionSuccess | pointsAwarded = 25 | High |
| TCF-T009 | Quick-complete from checkbox | Actionable task | TaskCompletionToggled | CompleteTask called, animation plays | High |
| TCF-T010 | On-behalf-of awards to selected member | Parent selects Alex | confirmCompletion() | completedByMemberId = alexId | High |

### 12.2 Widget Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TCF-W001 | PointsFlashWidget renders | pointsAwarded=15 | Render | "+15 pts" text visible | High |
| TCF-W002 | Confetti overlay appears | CompletionSuccess state | Render | Lottie widget visible | High |
| TCF-W003 | Photo required screen shows camera button | CompletionRequiresPhoto state | Render | "Take Photo" button visible | High |
| TCF-W004 | Verify button visible for parent on completed task | Parent, completed task | Render detail screen | "Verify" button visible | High |
| TCF-W005 | Verify button hidden for child | Child profile, completed task | Render detail screen | "Verify" button not found | High |
| TCF-W006 | On-behalf-of dialog shows members | 4 family members | Show dialog | 4 member items visible | Medium |

### 12.3 Edge Cases

- Double-tap on checkbox: only one completion triggered (debounce)
- Photo capture cancelled by user: return to CompletionRequiresPhoto state
- Camera not available (emulator): show "Camera not available" error
- Task completed by another user during animation: LWW conflict resolution applies
- Offline completion: celebration plays, sync badge increments
- Zero-point task: no points flash animation, confetti still plays
- Completion with all subtasks already checked vs some unchecked

---

## 13. Implementation Recommendations

### 13.1 Prototype Checklist

1. **What can a user do?** "As Alex, I can tap the checkbox on my 'Wash dishes' chore, see confetti explode across the screen, and watch '+15 pts' flash in gold. As Marcus, I can verify Alex's completion and see it in the history."
2. **Which screens are delivered?** TaskCompletionScreen (`/tasks/:taskId/complete`), PointsFlashWidget, verification dialog.
3. **What is the minimum data flow?** User taps checkbox -> CompleteTask use case -> Drift update (status=completed, completedByMemberId, completedAt) + points awarded -> stream update -> animation -> sync queued.
4. **What is the offline behavior?** Completion writes to Drift immediately. Points awarded locally. Celebration plays immediately. No internet needed. SyncOperation queued for later.
5. **What does "done" look like?** Tap checkbox on a 15-point task -> see scale animation on checkbox -> see "+15 pts" float up in gold -> see confetti for 2 seconds -> task background turns green -> pending sync badge shows 1.

### 13.2 Suggested Approach

1. Implement TaskCompletionCubit with all states and transitions.
2. Implement PointsFlashWidget with flutter_animate.
3. Build TaskCompletionScreen with all state-dependent layouts.
4. Add Lottie confetti overlay to CompletionSuccess state.
5. Integrate quick-complete into TaskCard (modify spec 20 widget).
6. Implement photo proof flow (capture, preview, compress).
7. Implement verification flow (dialog + VerifyTask call).
8. Implement "complete on behalf of" dialog.
9. Add haptic feedback patterns.
10. Test Emma's extended celebration.
11. Write cubit tests (10 tests).
12. Write widget tests (6 tests).

### 13.3 Estimated Effort

**M (3-5 days)** -- The completion flow involves multiple animation components and state transitions, but each is relatively small and self-contained. The photo proof flow adds complexity.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
