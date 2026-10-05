#!/usr/bin/env bash
# Installs or updates the pstack skills (Lauren Tan, MIT, github.com/cursor/plugins)
# and the working rules in ~/.claude, for cloud sessions and local machines alike.
#
# PSTACK_SHA is the reviewed upstream commit. A weekly routine reviews upstream
# changes and moves it; nothing upstream runs until it lands here.
# Safe to run every session: it does nothing when already on PSTACK_SHA, and it
# never fails the caller (a network error skips the update).

PSTACK_SHA=e5a8186d7b43be8d6ac4452440fbead5f1a51c70
PSTACK_SKILLS="unslop technical-writing teach how why tdd figure-it-out show-me-your-work"
PSTACK_GLOB="principle-*"   # with the 8 above: 32 skills at e5a8186
INSTALL_REV=2               # bump when this script changes what it installs, to force a reinstall

skills="$HOME/.claude/skills"
state="$skills/.pstack-sha"        # commit currently installed
managed="$skills/.pstack-managed"  # skills this script installed (it only ever touches these)

sync_skills() {
  mkdir -p "$skills"
  [ "$(cat "$state" 2>/dev/null)" = "$PSTACK_SHA r$INSTALL_REV" ] && return 0

  src=$(mktemp -d) || return 1
  trap 'rm -rf "$src"' RETURN
  git -C "$src" init -q &&
    git -C "$src" fetch -q --depth 1 https://github.com/cursor/plugins "$PSTACK_SHA" &&
    git -C "$src" checkout -q FETCH_HEAD || return 1

  # First run over an older install (no manifest yet): adopt same-named skills.
  if [ ! -f "$managed" ]; then
    (cd "$src/pstack/skills" && for s in $PSTACK_SKILLS $PSTACK_GLOB; do
      [ -d "$skills/$s" ] && echo "$s"; done) > "$managed"
  fi

  wanted=$(cd "$src/pstack/skills" && for s in $PSTACK_SKILLS $PSTACK_GLOB; do
    [ -d "$s" ] && echo "$s"; done)

  # Drop skills we installed that upstream no longer has.
  while read -r s; do
    [ -n "$s" ] && ! grep -qx "$s" <<<"$wanted" && rm -rf "${skills:?}/$s"
  done < "$managed"

  new_managed=""
  for s in $wanted; do
    if [ -e "$skills/$s" ] && ! grep -qx "$s" "$managed"; then
      echo "pstack: leaving your own '$s' skill alone" >&2
      continue
    fi
    rm -rf "${skills:?}/$s" && cp -R "$src/pstack/skills/$s" "$skills/$s" || return 1
    # Upstream marks every skill typed-only (disable-model-invocation: true), so
    # Claude can't start them itself, e.g. unslop before a reply. Olushola approved
    # dropping that frontmatter line on 5 Oct 2026 so the working rules can be followed.
    awk 'NR==1 && /^---/ {fm=1; print; next}
         fm && /^---/ {fm=0}
         fm && /^disable-model-invocation:/ {next} {print}' \
      "$skills/$s/SKILL.md" > "$skills/$s/SKILL.md.tmp" &&
      mv "$skills/$s/SKILL.md.tmp" "$skills/$s/SKILL.md"
    new_managed="$new_managed$s"$'\n'
  done
  printf '%s' "$new_managed" > "$managed"
  echo "$PSTACK_SHA r$INSTALL_REV" > "$state"
  echo "pstack: skills at ${PSTACK_SHA:0:7} ($(grep -c . "$managed") installed)" >&2
}

sync_skills || echo "pstack: update skipped (fetch failed), keeping what is installed" >&2

if ! grep -qs "pstack working rules" "$HOME/.claude/CLAUDE.md"; then
  mkdir -p "$HOME/.claude"
  cat >> "$HOME/.claude/CLAUDE.md" <<'RULES'

## pstack working rules
These apply to you and to every subagent you brief. A project's own rules win where they are stricter.
- Before building, understand the problem and sketch the data shape. For a bug, reproduce it first and fix the root cause (principle-fix-root-causes).
- Keep changes small. Delete code before adding abstractions (principle-laziness-protocol, principle-subtract-before-you-add).
- Done means proven. Run the real thing and show the output, screenshot or test result before you call it finished (principle-prove-it-works).
- Break multi-step work into small steps that each end in a check (principle-sequence-verifiable-units). Keep a short decision log on long work (show-me-your-work).
- Don't stop to ask about reversible choices. Decide, do it, and say what you chose (principle-never-block-on-the-human). Ask before anything irreversible: deleting data, force-pushing, spending money, merging, or sending anything outside.
- Every subagent brief states the goal, the context it needs, how the work will be verified, and what to report back.
- Run unslop on anything people will read (summaries, docs, posts, PR descriptions). Use technical-writing for guides and READMEs. Use UK spelling and no em dashes.
- pstack was written for Cursor. Read "Task" as the Agent tool and `generalPurpose` as `general-purpose`. Ignore `pstack-models.mdc` and the grok model defaults. poteto-mode, architect, arena and swarm are not installed, so skip steps that call them, including the cross-model review in show-me-your-work.
RULES
fi
exit 0
