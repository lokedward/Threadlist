# Closet Tracker - Manual Test Plan

This document outlines the manual testing procedures for all major features within the Closet Tracker application.

---

## 🏗️ 1. Item Addition Flow (AddItemView)

### 1.1 Single Item Addition
- [ ] **Photo Selection (Gallery)**: Tap "ADD PHOTOGRAPH" -> Select "Choose from Library" -> Pick an image.
    - *Expected*: The `CropView` should open immediately.
- [ ] **Photo Selection (Camera)**: Tap "ADD PHOTOGRAPH" -> Select "Take Photo" -> Capture an image.
    - *Expected*: The `CropView` should open after capture.
- [ ] **Cropping**: Adjust the crop area and hit "Apply".
    - *Expected*: The cropped image appears in the `AddItemView`.
- [ ] **Metadata Entry**: Type into Name, Category, Brand, Size, and Tags.
    - *Expected*: Zero lag while typing, even with high-res images loaded.
- [ ] **Form Validation**: Try to save without a name or category.
    - *Expected*: The "SAVE TO CLOSET" button should remain disabled.
- [ ] **Saving**: Tap "SAVE TO CLOSET".
    - *Expected*: The view dismisses and the item appears in the Home/Category grid.

### 1.2 Bulk Item Addition
- [ ] **Mode Toggle**: Switch the top picker to "MULTIPLE".
    - *Expected*: The UI switches to the bulk upload layout.
- [ ] **Multi-Selection**: Tap "OPEN GALLERY" -> Select 5+ images -> Tap "Add".
    - *Expected*: The processing overlay appears, then the first image of the queue is shown.
- [ ] **Queue Management**: Verify the header says "ITEM 1 OF X".
    - *Expected*: Correct numbering for the batch.
- [ ] **Metadata Persistence**: Save the first item with a specific Category and Brand.
    - *Expected*: The second item should inherit the Category and Brand from the previous one.
- [ ] **Save & Next**: Tap "SAVE & NEXT".
    - *Expected*: The current item saves, and the next image in the queue is presented.
- [ ] **Batch Completion**: Save the last item in the batch.
    - *Expected*: The view dismisses after the final "SAVE & FINISH".
- [ ] **Cancellation**: Start a batch, save 1 item, then tap "Cancel" for the 2nd.
    - *Expected*: The first item should remain saved; others should be discarded.

---

## 🏠 2. Home & Navigation

### 2.1 Dashboard (HomeView)
- [ ] **Category Shelves**: Scroll through the horizontal category shelves.
    - *Expected*: Smooth scrolling and clear thumbnails.
- [ ] **Item Navigation**: Tap an item thumbnail.
    - *Expected*: Navigates to the `ItemDetailView` for that item.

### 2.2 Category Grid
- [ ] **Full View**: Tap "View All" on a category shelf.
    - *Expected*: Navigates to a full grid of items in that category.

---

## 🔍 3. Search & Discovery

### 3.1 Search View
- [ ] **Keyword Search**: Type a name or brand into the search bar.
    - *Expected*: Results filter in real-time.
- [ ] **Tag Filtering**: Tap a tag in the search results.
    - *Expected*: Filters items by the selected tag.
- [ ] **Empty States**: Search for a non-existent item.
    - *Expected*: Shows a clean "No items found" message.

---

## 📁 4. Category Management

### 4.1 Management View
- [ ] **Add Category**: Tap "Add Category" -> Enter name -> Choose icon.
    - *Expected*: Category appears in the list and home screen.
- [ ] **Reordering**: Drag and drop categories to change order.
    - *Expected*: The order persists in the main app.
- [ ] **Deletion**: Swipe to delete a category.
    - *Expected*: Confirmation dialog appears (if implemented) or category is removed.

---

## ⚙️ 5. Settings & Theme

### 5.1 Theme Testing
- [ ] **Light Mode**: toggle system settings to Light Mode.
    - *Expected*: PoshTheme colors (Champagne, White) apply correctly.
- [ ] **Dark Mode**: toggle system settings to Dark Mode.
    - *Expected*: PoshTheme colors (Bronze, Dark Gray) and bronze glow shadows apply correctly.

---

## 🛠️ 6. Performance & Stability

- [ ] **Large Selection**: Test selecting 50 images in Bulk Mode.
    - *Expected*: No crashes; processing progress is visible.
- [ ] **Memory Management**: Rapidly cycle through categories and items.
    - *Expected*: No significant lag or memory pressure spikes.
