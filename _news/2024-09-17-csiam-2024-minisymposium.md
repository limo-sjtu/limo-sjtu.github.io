---
layout: post
title: LIMO co-organizes a mini-symposium at CSIAM 2024
description: LIMO members are co-organizing a mini-symposium on inverse problems and computational imaging at CSIAM 2024.
date: 2024-09-17
kind: event
inline: false
related_posts: false
---

We are co-organizing a mini-symposium at CSIAM 2024 Annual Meeting.

{% for item in site.data.activity.events %}
{% if item.id == 'csiam2024' %}

<div class="limo-activity-list">
{% include limo/activity-event-row.liquid item=item heading_level=2 %}
</div>
{% endif %}
{% endfor %}
