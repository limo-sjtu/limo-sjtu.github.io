---
layout: page
permalink: /people/
title: People
description: Members of the lab.
nav: true
nav_order: 3
display_categories: [Faculty, Post-doc, PhD student, Master student, Undergraduate, Alumni]
---

<!-- pages/people.md -->
<div class="people">

  <!-- Display non-empty people categories -->

{% for category in page.display_categories %}
{% assign categorized_people = site.people | where: "category", category %}
{% if categorized_people.size > 0 %}
{% assign category_id = category | slugify %}
<a id="{{ category_id }}" href="#{{ category_id }}">

<h4 class="category">{{ category }}</h4>
</a>

    {% assign sorted_people = categorized_people | sort: "importance" %}
    <div class="container">
      <div class="row row-cols-1 row-cols-md-2">
      {% for people in sorted_people %}
        {% include people.liquid %}
      {% endfor %}
      </div>
    </div>

{% endif %}
{% endfor %}

</div>
