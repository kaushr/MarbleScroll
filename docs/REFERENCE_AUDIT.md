# Reference provenance

Reference fork: https://github.com/kaushr/drag-scroll

Upstream: https://github.com/emreyolcu/drag-scroll

Both reference clones had HEAD `879bd0e6f4f1aae239364c5e7e49f19746729993` before documentation was added. All nine tracked file paths, modes and Git blob IDs match; a directory diff excluding `.git` and Finder `.DS_Store` was empty. The completed nine-file static audit therefore applies to the fork's unchanged implementation at this commit as well as upstream. No reference source was built or executed.

Audit preserved in fork: https://github.com/kaushr/drag-scroll/blob/48fabc0/docs/SECURITY_AUDIT.md

Only `docs/SECURITY_AUDIT.md` was added to that fork; its existing code was unchanged. The original audit was also preserved at `../docs/SECURITY_AUDIT.md` in the local parent workspace. No upstream files were modified. New MarbleScroll source lives solely in this independent directory/repository.

Behavioral influence: button-activated trackball scrolling, two axes and user speed/direction preferences. No literal source, event tap setup, permission recovery, cursor warping or local suppression logic was reused. MIT attribution is acknowledgment of influence, not a claim that this implementation shares tested safety characteristics with DragScroll.

The prior high operational risk gate was explicitly approved for Option B development. New native input handling still requires separate permission/live-test approval.
