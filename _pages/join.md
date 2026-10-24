---
layout: page
title: Join Us
permalink: /join/
description: Opportunities to join or collaborate with the LIMO Lab.
nav: true
nav_order: 6
---

<p class="limo-page-lead">
  {{ site.data.recruitment.lead }}
</p>

<div class="limo-join-grid">
  {% for opportunity in site.data.recruitment.opportunities %}
    <section class="limo-join-card">
      <p class="limo-join-card__eyebrow">Opportunities</p>
      <h2>{{ opportunity.title }}</h2>
      <p>{{ opportunity.description }}</p>
    </section>
  {% endfor %}
</div>

## How to inquire

Please send a concise email to **{{ site.data.recruitment.contact_email }}** with:

{% for requirement in site.data.recruitment.inquiry_requirements %}
{{ forloop.index }}. {{ requirement }}{% if forloop.last %}.{% else %};{% endif %}
{% endfor %}

{{ site.data.recruitment.availability_note }}

## Collaboration and visits

{{ site.data.recruitment.collaboration }}

## Location

{% for line in site.data.recruitment.location %}
{{ line }}{% unless forloop.last %} {% endunless %}
{% endfor %}

Learn more about our [research]({{ '/research/' | relative_url }}), [members]({{ '/people/' | relative_url }}), and [publications]({{ '/publications/' | relative_url }}).
