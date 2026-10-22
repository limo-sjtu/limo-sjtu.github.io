# LIMO website maintenance guide

This repository uses a request-and-review workflow. Lab members submit facts through GitHub Issue Forms; the website maintainer decides what to publish, prepares the file changes, reviews the pull request, and merges it. Submitting a request never changes the website automatically.

## Roles and access

| Role               | Access                                  | Responsibility                                                 |
| ------------------ | --------------------------------------- | -------------------------------------------------------------- |
| Lab member         | Open and comment on issues              | Submit complete, public, accurate information                  |
| Website maintainer | Write access and pull-request review    | Accept, revise, or reject requests; implement accepted changes |
| GitHub Actions     | Read repository contents and run checks | Reject structurally invalid content and failed builds          |

Members do not need direct write access. The maintainer remains the code owner for the repository through `.github/CODEOWNERS`.

## Request lifecycle

1. A member opens a [website update request](https://github.com/limo-sjtu/limo-sjtu.github.io/issues/new/choose).
2. The maintainer checks the request and records one of these decisions in a comment:
   - **Accepted** — implement the request as submitted.
   - **Revision requested** — ask the submitter for missing or corrected facts.
   - **Accepted with revisions** — the maintainer adjusts wording or structure while preserving the facts.
   - **Rejected** — close the request with a short reason.
3. For an accepted request, create a branch and a pull request that contains `Closes #<issue-number>`.
4. Review the generated diff, automated validation, Jekyll build, and affected pages.
5. Merge to `master`. Close the issue only after the deployed page is correct.

Recommended labels are `status: needs review`, `status: revision requested`, `status: accepted`, and `status: rejected`. Labels are optional; the issue and linked pull request remain the audit trail.

## Sources of truth

| Content                              | Canonical files                    |
| ------------------------------------ | ---------------------------------- |
| Member directory entry and biography | `_people/<member-id>.md`           |
| Structured member CV                 | `_data/cv/<member-id>.yml`         |
| Member portrait                      | `assets/img/people/<filename>`     |
| Publications                         | `_bibliography/papers.bib`         |
| News                                 | `_news/YYYY-MM-DD-<short-slug>.md` |

Do not create a second bibliography, a second member-layout protocol, or an additional copy of publication data. Historical CV publication lists may remain, but new publications must first be added to `papers.bib`.

## Member schema

Use a lowercase `firstname_lastname` identifier for new members. The page and CV filenames must share the same identifier.

Internal profile:

```yaml
---
layout: cvpage
title: Full Name
img: portrait.jpg
cv: firstname_lastname
toc:
  sidebar: right
importance: 10
category: PhD student
webpage: true
scholar:
github:
---
Short biography.
```

Redirect-only profile:

```yaml
---
layout: page
title: Full Name
img: portrait.jpg
importance: 10
category: Faculty
redirect: https://example.edu/profile
webpage: true
scholar:
github:
---
```

Allowed categories are `Faculty`, `Post-doc`, `PhD student`, `Master student`, `Undergraduate`, and `Alumni`. `importance` is an integer used for ordering within a category. Use full `https://` URLs for public links and verify that the portrait filename matches its case exactly.

CV data is a list of sections. Supported section types are `map`, `time_table`, `publications`, `list`, `nested_list`, and `list_groups`. Remove empty sections instead of leaving template placeholders in production data. A publication URL is optional in an existing CV entry; the template renders plain text when no URL is present.

## Publication schema

`_bibliography/papers.bib` is the only bibliography. Each citation key and each field inside an entry must be unique.

```bibtex
@article{author2026keyword,
  title={Paper Title},
  author={Last, First and Last, First},
  journal={Journal Name},
  year={2026},
  abbr={Journal},
  bibtex_show={true},
  html={https://doi.org/...},
  cate_primary={optimization},
  cate_secondary={none},
  selected={false},
}
```

Rules for new entries:

- Use `@article`, `@inproceedings`, or `@phdthesis` as appropriate.
- `abbr` must be `Journal`, `Conference`, `Preprint`, or `Thesis`.
- `cate_primary` must be `imaging`, `optimization`, or `learning`.
- `cate_secondary` is optional and may use the same values or `none`.
- `bibtex_show` and `selected` must be explicit booleans.
- Add a DOI or public `html` link. Historical entries without links are allowed temporarily and reported as a warning.
- Add `abstract` only when real abstract text is available; omit empty fields.
- The maintainer decides `selected`; submitters do not decide homepage placement.

## News schema

Filename: `_news/YYYY-MM-DD-short-slug.md`.

```yaml
---
layout: post
title: Short descriptive title
date: YYYY-MM-DD
kind: publication
inline: true
related_posts: false
---
Concise Markdown announcement with public links where useful.
```

Allowed `kind` values are `publication`, `event`, `award`, `member`, and `general`. Use `inline: true` for a short list item and `inline: false` for a longer standalone page. News is explicitly sorted by its front-matter date.

## Local checks

Run the structural validator first:

```bash
ruby scripts/validate_content.rb
```

Then build the site:

```bash
bundle exec jekyll build
```

The repository excludes the unused demonstration notebook from the build, so Jupyter is not required for ordinary website maintenance. When layout, images, or rendered text changes, also inspect the affected page in a local browser preview.

## Repository protection to enable on GitHub

The repository files prepare the workflow, but an owner must enable branch protection in GitHub settings:

1. Create a ruleset for the `master` branch.
2. Require changes through pull requests.
3. Require at least one approval and require code-owner review.
4. Require the `Validate website content / validate` status check and the site build check.
5. Block force pushes and branch deletion.
6. Limit bypass permission to the website maintainer or repository administrators.

This is the access-control boundary: members can submit requests without permission to merge or publish, while the maintainer retains the final decision.
