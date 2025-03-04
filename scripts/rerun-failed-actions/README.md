** Rerun failed actions **

== Process GPML changes ==

If this action fails, first address the issue or bug, and then trigger the action again for the files that failed. 

* Collect the filepaths from the *changed-gpmls* job in the workflow run, expand the "Get changed files" step.
* If it's only a small number of files, then you can simply open each of the GPMLs (e.g., in VSCode) and add a newline character to the end of each file.
* If it's a large number of files, then you can copy/paste the list of filepaths into a text file in the top level directory, e.g., `files.txt` (see example in this directory). And then run a one-liner to add the newline characters.
    * macOS> ```while IFS= read -r file; do printf '\n' >> "$file"; done < files.txt```
    * windows> ```for /f %f in (files.txt) do echo >> %f```
* Then commit the changes and push to the repository. This will trigger the action again.
