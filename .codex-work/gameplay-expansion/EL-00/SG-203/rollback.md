# SG-203 rollback

SG-203 changed no production file, tuning value, save, build, or itch artifact.
There is no gameplay rollback to perform.

Retain this directory as failed-verdict evidence. To roll back only the
coordinator bookkeeping, revert the future SG-203 closure record and restore
the serialization cursor to accepted AB-01 commit `52ffb79`. Do not delete or
rewrite the original BASE-00 artifacts. EL-00 remains blocked until a separately
claimed repair produces an accepted control.
