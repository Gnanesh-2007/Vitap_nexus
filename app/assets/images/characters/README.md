# Character packs

Put extra characters here to make them appear in Profile, Appearance, Widget character.

Each character needs four round-sticker pictures, named `{id}_{mood}.png`:

| Mood | Shown when |
| :--- | :--- |
| `fight` | you are in class |
| `run` | a class is about to start |
| `peace` | you are free, or done for the day |
| `eye` | on the exam widget |

For the widgets, copy the same four files to `android/app/src/main/res/drawable-nodpi/` as `widget_art_{id}_{mood}.png`, and add the character to `WidgetCharacter.packs` in `lib/services/widget_character.dart` and to the id list in `WidgetUpdater.kt`.

The pictures that ship with a private build are third-party artwork and are not part of this repository.
