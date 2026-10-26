# Changelog

All notable changes to Inspector will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Storage view with safety-tiered catalog of known caches and leftovers.
- Disk snapshot in header.
- Each item shows the icon of the app it belongs to, taken from the installed app.
- Details inspector with what an item is, what removing it does, when it was last modified, and where it lives.
- Last-modified date for every item.
- Keyboard navigation: arrow keys move, Space selects, ⌘⌫ moves the selection to the Trash.

### Changed
- Removing items moves them to the Trash with Undo instead of deleting them permanently. Selections that include Review or Keep items ask first.

### Notes
- First preview. Not yet signed. Direct `.dmg` distribution planned.
