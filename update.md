# LIMO website maintenance guide

For workflow governance, access control, review states, deployment, rollback,
and rollout planning, see [WEBSITE_UPDATE_WORKFLOW.md](WEBSITE_UPDATE_WORKFLOW.md).
This guide defines the content schemas and day-to-day editing procedures.

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
| Principal Investigator page          | `_pages/pi.md`                     |
| Member portrait                      | `assets/img/people/<filename>`     |
| Research-area descriptions           | `_data/research_areas.yml`         |
| Publication-topic taxonomy           | `_data/publication_topics.yml`     |
| Publications                         | `_bibliography/papers.bib`         |
| News                                 | `_news/YYYY-MM-DD-<short-slug>.md` |
| Events, talks, and service           | `_data/activity/*.yml`             |
| Recruitment information              | `_data/recruitment.yml`            |

Do not create a second bibliography, a second member-layout protocol, or an additional copy of publication data. A historical CV publication list may remain only for work that is not yet in `papers.bib`; once a paper is added to the central bibliography, remove its duplicate CV entry.

The PI is an intentional exception to the general member-page pattern. Keep the directory metadata in `_people/xiaoqun_zhang.md` and maintain the complete standalone profile only in `_pages/pi.md`. The People card and the generated `/people/xiaoqun_zhang/` redirect both lead to `/pi/`; do not assign that permalink to the collection record as well.

## Member schema

Use a stable lowercase `firstname_lastname` identifier for every member. The `_people` filename, its `member_id`, and (for an internal profile) the CV filename and `cv` value must match. Do not change `member_id` when a member graduates: publication-to-profile links depend on it. A rename requires a reviewed URL migration and an update to every matching `limo_members` field.

Internal profile:

```yaml
---
layout: limo-member
title: Full Name
member_id: firstname_lastname
description: One-sentence public profile summary.
img: portrait.jpg
cv: firstname_lastname
toc:
  sidebar: right
importance: 10
category: PhD student
position: PhD Student
sort_name: Lastname Firstname
status: current
research_areas: [imaging, optimization]
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
member_id: firstname_lastname
description: One-sentence public profile summary.
img: portrait.jpg
importance: 10
category: Faculty
position: Professor
status: current
redirect: https://example.edu/profile
sitemap: false
webpage: true
scholar:
github:
---
```

Allowed categories are `Faculty`, `Post-doc`, `PhD student`, `Master student`, `Undergraduate`, and `Alumni`. Use `status: current` for current members and `status: alumni` with the `Alumni` category for former members. Optional `research_areas` values are `imaging`, `optimization`, and `learning`; only add areas supported by the member's submitted biography. PhD students, master's students, and alumni require `sort_name` in `Family-name Given-name` pinyin order and are displayed alphabetically by that field. Alumni also require `alumni_degree: phd` or `alumni_degree: masters`, which controls their subgroup. Other categories use the integer `importance` field for ordering. Use full `https://` URLs for public links and verify that the portrait filename matches its case exactly. A `redirect` may instead use a root-relative path such as `/pi/` when it intentionally preserves a historical internal URL.

CV data is a list of sections. Supported section types are `map`, `time_table`, `publications`, `list`, `nested_list`, and `list_groups`. Each `map` row requires `name` and either a non-empty `value` or a non-empty `links` list of `{name, link}` records. Remove empty sections instead of leaving template placeholders in production data. A publication URL is optional in an existing CV entry; the template renders plain text when no URL is present.
Use scalar dates in `YYYY.MM - YYYY.MM` form, or `YYYY.MM - Present` only for genuinely current activities. Alumni education must not end in `Now` or `Present`; use `Completed` when the exact graduation date has not been confirmed rather than inventing a date. Do not publish literal email addresses; use the anti-spam `name at domain dot com` form, and remove rows whose value is only `None` or `N/A`.

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
  limo_members={firstname_lastname},
  selected={false},
  homepage_featured={false},
}
```

Rules for new entries:

- Use `@article`, `@inproceedings`, or `@phdthesis` as appropriate.
- `abbr` must be `Journal`, `Conference`, `Preprint`, or `Thesis`.
- `cate_primary` must be an ID from `_data/publication_topics.yml`.
- `cate_secondary` is optional and may use a taxonomy ID or `none`.
- `limo_members` is an optional comma-separated list of profile `member_id` values, for example `{firstname_lastname, second_member}`. Include every LIMO author whose local profile should show the paper; the member page creates its Publications section automatically and omits the section when there are no matches. This internal field is removed from the public BibTeX panel. Do not type publication lists into profile Markdown or CV data.
- `bibtex_show`, `selected`, and (when present) `homepage_featured` must be booleans.
- Add a DOI or public `html` link. Historical entries without links are allowed temporarily and reported as a warning.
- Add `abstract` only when real abstract text is available; omit empty fields.
- The maintainer decides `selected` and `homepage_featured`; submitters do not decide homepage placement. Exactly three entries must set `homepage_featured={true}`, and each must also set `selected={true}`.

## News schema

Filename: `_news/YYYY-MM-DD-short-slug.md`.

```yaml
---
layout: post
title: Short descriptive title
description: One-sentence summary used by previews and metadata.
date: YYYY-MM-DD
kind: publication
publication_key: author2026keyword
inline: true
related_posts: false
---
Concise Markdown announcement with public links where useful.
```

Allowed `kind` values are `publication`, `preprint`, `event`, `award`, `member`, `recruiting`, `grant`, and `general`. Every item requires `description`. Publication and preprint news also requires `publication_key`, which must exactly match an entry in `_bibliography/papers.bib`. Use `inline: true` for a short list item and `inline: false` for a longer standalone page. News is explicitly sorted by its front-matter date.

Reserve News for meaningful lab updates: awards, defenses and graduations, visitors and events, new members, grants, recruiting, and selected publication milestones. Routine bibliography additions belong only in `_bibliography/papers.bib`; they do not require a duplicate News item.

## Site content architecture

The primary navigation is `Research`, `PI`, `People`, `Publications`, `News`, and `Join Us`. The standalone PI page at `/pi/` is also available from the Faculty card below People.

Research-area names and descriptions are maintained once in `_data/research_areas.yml`. Publication filters and labels are maintained once in `_data/publication_topics.yml`; research areas refer to those topics by ID. The homepage cards and the full Research page read these files. Each research-area entry requires a stable lowercase `id`, a title, summary, description, methods, applications, and one or more valid publication-topic IDs. Do not duplicate these descriptions or labels directly in page templates.

The homepage is a curated overview rather than a complete archive:

- three research areas come from `_data/research_areas.yml`;
- exactly three featured papers come from bibliography entries with `homepage_featured={true}`;
- five recent non-featured publications, including preprints, come from the bibliography;
- five recent News items come from `_news/`;
- recruitment details link to `_pages/join.md`.

The maintainer controls `selected`, `homepage_featured`, and homepage placement. Member requests may propose a highlight, but publication acceptance does not automatically make an item featured.

## Activity schema

Activity pages read only from `_data/activity/`: `events.yml`, `talks.yml`, and `services.yml`. Submit activity changes with the Activity Issue Form so the maintainer receives the same facts these files require.

- Event rows require a lowercase `id`; ISO `start_date` and `end_date`; a human-readable `date_display`; `session`, `conference`, and `location`; `lang` (`en` or `zh-CN`); and a non-empty `organizers` list whose entries contain `name` and `affiliation`. URLs are optional but must be full `http(s)` links when present.
- Talk rows require a lowercase `id`; ISO `start_date` and `end_date`; `date_display`; `title`, `conference`, and `location`; and `lang` (`en` or `zh-CN`). Optional slides may be a full URL or a root-relative file below the repository. Delete empty placeholder rows.
- Service sections use `type: service` with `year`, `role`, and `venue`, or `type: review` with named groups whose `description` is a list of venues. Avoid duplicate venue entries.

## Local checks

Run the structural validator first:

```bash
ruby scripts/validate_content.rb
```

Install the pinned Node tools with `npm ci` before running formatting, CSS purging, or accessibility checks locally.

Then build the site:

```bash
bundle exec jekyll build
```

For any dependency, layout, include, JavaScript, or Sass change, also run the
theme compatibility checks:

```bash
bundle exec al-folio upgrade audit
bundle exec al-folio upgrade overrides audit --fail-on-stale
```

The website does not publish notebooks, so the Jupyter build plugin is not installed. If notebook content is introduced later, add and test that support deliberately rather than committing an `.ipynb` file alone. When layout, images, or rendered text changes, also inspect the affected page in a local browser preview.

## Theme architecture and upgrades

The al-folio runtime is supplied by versioned gems in `Gemfile.lock`. Site-owned
presentation code is deliberately namespaced so that a theme update does not
silently replace it:

| Responsibility     | Location                                                      |
| ------------------ | ------------------------------------------------------------- |
| LIMO layouts       | `_layouts/limo-*.liquid`                                      |
| LIMO components    | `_includes/limo/`                                             |
| LIMO styles        | `_sass/limo/`                                                 |
| Structured content | `_people/`, `_data/cv/`, `_news/`, `_bibliography/papers.bib` |

Two intentional theme overrides remain and both are recorded in
`.al-folio-overrides.yml`:

- `_layouts/default.liquid` provides the redirect-page handling used by local profiles.
- `assets/css/main.scss` loads the upstream Sass modules and then the LIMO Sass
  entry point.

The customized header and bibliography renderer use the site-owned
`_includes/limo/header.liquid` and `_layouts/limo-bib.liquid` paths, so they no
longer shadow upstream theme files.

`_plugins/limo_css_cache_bust.rb` extends al-folio's stylesheet fingerprint to
include the site-owned `_sass/` files. Keep this plugin while LIMO styles live
outside the theme gem; otherwise browsers may continue using an older
`main.css` after a local style update.

Do not add a local file with the same path as an al-folio layout, include,
JavaScript file, or Sass partial unless an override is unavoidable. Prefer a
new `limo-*` layout or a component below `_includes/limo/`.

To update al-folio:

1. Create a dedicated branch and update the pinned al-folio gems and lockfile.
2. Run `bundle exec al-folio upgrade audit` and the override audit shown above.
3. Review the upstream diff for each reported override before acknowledging it.
4. Run the content validator and a clean Jekyll build.
5. Inspect the homepage, People, Publications, one member CV, and mobile
   navigation before merging.

If an intentional override changes after review, acknowledge only that path:

```bash
bundle exec al-folio upgrade overrides accept _layouts/bib.liquid
```

Never run `overrides accept --all` merely to silence a warning; the manifest is
the review record for upstream-sensitive files.

## Repository protection to enable on GitHub

The repository files prepare the workflow, but an owner must enable branch protection in GitHub settings:

1. Create a ruleset for the `master` branch.
2. Require changes through pull requests.
3. Require at least one approval and require code-owner review.
4. Require the `Validate website content / validate` status check and the site build check.
5. Block force pushes and branch deletion.
6. Limit bypass permission to the website maintainer or repository administrators.

This is the access-control boundary: members can submit requests without permission to merge or publish, while the maintainer retains the final decision.
