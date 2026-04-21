{{/*
  Subscriptions the product has turned on (values.*.enabled), without regard to OLM or the cluster.
  The manifest that creates Subscription objects does not use this
  template; it uses subscriptions.managed, which implements a different policy (see below).
*/}}
{{- define "subscriptions.enabled" -}}
  {{- $out := dict -}}
  {{- range $k, $v := .Values.subscriptions -}}
    {{- if $v.enabled -}}
      {{- $out = merge $out (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $out | toYaml -}}
{{- end -}}

{{/*
  Low-level check: is a single Subscription object (item) part of *this* Helm release? Pass the
  chart context as .root and the cluster Subscription as .item. Emits the string "true" or "false"
  (include+trim) for use in other templates. Used by subscriptions.managedSubscriptions to filter
  a live list; it is the only place that interprets Helm label/annotation metadata.
*/}}
{{- define "subscriptions.itemOwnedByRelease" -}}
  {{- $root := .root -}}
  {{- $item := .item -}}
  {{- $meta := $item.metadata | default dict -}}
  {{- $lb := $meta.labels | default dict -}}
  {{- $an := $meta.annotations | default dict -}}
  {{- if and
      (eq (index $lb "app.kubernetes.io/managed-by" | default "") "Helm")
      (eq (index $an "meta.helm.sh/release-name" | default "") $root.Release.Name)
      (eq (index $an "meta.helm.sh/release-namespace" | default "") $root.Release.Namespace)
  -}}
true
  {{- else -}}
false
  {{- end -}}
{{- end -}}

{{/*
  Cluster snapshot for subscriptions.managed "auto": lists OLM package names (Subscription
  spec.name) for Subscriptions anywhere on the cluster that belong to this release (see
  itemOwnedByRelease). Namespace and Subscription metadata.name are ignored so operators installed
  under unexpected names/locations still match by package id. Requires listing Subscription CRs;
  feeds managed (coerce fromYaml to a slice, then match by spec.name). External or foreign
  Subscriptions without Helm labels never appear here.
*/}}
{{- define "subscriptions.managedSubscriptions" -}}
  {{- $root := . -}}
  {{- $pkgs := list -}}
  {{- $list := lookup "operators.coreos.com/v1alpha1" "Subscription" "" "" -}}
  {{- $items := ($list | default dict).items | default list -}}
  {{- range $items -}}
    {{- if eq ((include "subscriptions.itemOwnedByRelease" (dict "root" $root "item" .)) | trim) "true" -}}
      {{- with (dig "spec" "name" "" .) -}}
        {{- $pkgs = append $pkgs . -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $pkgs | compact | uniq | toYaml -}}
{{- end -}}

{{/*
  Which values.subscriptions entries become Subscription/OperatorGroup manifests.

  Flow for managed "auto": (1) If this release already owns that OLM package on the cluster, the
  package appears in managedSubscriptions → include. (2) Else if apiResource’s CRD is absent, assume
  the operator is not installed and include so OLM can install it. (3) If the CRD exists but the
  package is not in managedSubscriptions, skip (operator present from elsewhere; avoid duplicating).

  Flow for managed "true": include regardless of cluster (explicit opt-in).

  Compare subscriptions.enabled (product toggle for tests/notes) vs this template (what we actually
  install). NOTES should follow managed so output matches subscriptions.yaml.
*/}}
{{- define "subscriptions.managed" -}}
  {{- $out := dict -}}
  {{- $parsed := include "subscriptions.managedSubscriptions" . | fromYaml -}}
  {{- $ownedPkgs := list -}}
  {{- if kindIs "slice" $parsed -}}
    {{- $ownedPkgs = $parsed -}}
  {{- end -}}
  {{- range $k, $v := .Values.subscriptions -}}
    {{- $take := false -}}
    {{- if eq $v.managed "auto" -}}
      {{- if $v.name -}}
        {{- range $ownedPkgs -}}
          {{- if eq . $v.name -}}{{- $take = true -}}{{- end -}}
        {{- end -}}
      {{- end -}}
      {{- if and (not $take) $v.apiResource -}}
        {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" $v.apiResource -}}
        {{- if not (index $crd "metadata") -}}
          {{- $take = true -}}
        {{- end -}}
      {{- end -}}
    {{- else -}}
      {{- $take = eq $v.managed "true" -}}
    {{- end -}}
    {{- if $take -}}
      {{- $out = merge $out (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $out | toYaml -}}
{{- end -}}
