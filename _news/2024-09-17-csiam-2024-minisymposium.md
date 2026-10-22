---
layout: post
title: LIMO co-organizes a mini-symposium at CSIAM 2024
date: 2024-09-17
kind: event
inline: true
related_posts: false
---

We are co-organizing a mini-symposium at CSIAM 2024 Annual Meeting.

{% assign total=site.data.activity.events %}

<div class="table-list-innews">
    <table class="">
      <tbody>
        {% for item in total %}
          {% if item.id=="csiam2024" %}
            <tr>
              <td class="percentage-width-innews">
                <h6 class="item-badge-innews" style="">
                <b>{{- item.date -}} {{ ", " }} {{ item.year -}}</b>
                </h6>
              </td>
              <td class="second-row-info">
                <div style="margin-left:0.75rem;">
                {% if item.session_url %}<a href="{{ item.session_url }}">{{ item.session }}</a>{% else %}{{ item.session }}{% endif %}
                 <br>
                {% if item.language=="Chinese" %}
                  <b>组织者</b>: {{ item.organizers }} 
                {% else %}
                  <b>Organizers</b>: {{ item.organizers }}
                {% endif %}
                <br>
                  <a href="{{ item.conf_url }}" style="font-weight: bold;">{{ item.conference }}</a> @ <a>{{ item.location }}</a> 
                  </div>
              </td>
            </tr>
            {% endif %}
        {% endfor %}
      </tbody>
    </table>
</div>
