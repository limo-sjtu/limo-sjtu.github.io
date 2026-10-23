---
layout: page
title: Research
permalink: /research/
description: Research directions of the LIMO Lab.
nav: true
nav_order: 1
---

<p class="limo-page-lead">
  LIMO studies the mathematical and computational foundations of imaging and data science. Our work connects rigorous analysis with algorithms designed for real measurement, reconstruction, and learning problems.
</p>

<nav class="limo-research-jump" aria-label="Research areas">
  {% for area in site.data.research_areas %}
    <a href="#{{ area.id }}">{{ area.title }}</a>
  {% endfor %}
</nav>

<div class="limo-research-details">
  {% for area in site.data.research_areas %}
    <section id="{{ area.id }}" class="limo-research-detail" aria-labelledby="{{ area.id }}-title">
      <p class="limo-research-detail__number" aria-hidden="true">0{{ forloop.index }}</p>
      <div class="limo-research-detail__body">
        <h2 id="{{ area.id }}-title">{{ area.title }}</h2>
        <p class="limo-research-detail__summary">{{ area.summary }}</p>
        <p>{{ area.description }}</p>

        <div class="limo-research-detail__lists">
          <div>
            <h3>Methods</h3>
            <ul>
              {% for item in area.methods %}
                <li>{{ item }}</li>
              {% endfor %}
            </ul>
          </div>
          <div>
            <h3>Applications</h3>
            <ul>
              {% for item in area.applications %}
                <li>{{ item }}</li>
              {% endfor %}
            </ul>
          </div>
        </div>

        <div class="limo-research-detail__links" aria-label="Publication links for {{ area.title | escape }}">
          {% for topic in area.publication_topics %}
            <a href="{{ '/publications/?topic=' | append: topic.id | relative_url }}">{{ topic.label }} <span aria-hidden="true">→</span></a>
          {% endfor %}
        </div>
      </div>
    </section>

{% endfor %}

</div>
