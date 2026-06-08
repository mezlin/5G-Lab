# Graph Report - .  (2026-06-05)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 272 nodes · 203 edges · 97 communities (30 shown, 67 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `94b4dfa1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 95|Community 95]]
- [[_COMMUNITY_Community 96|Community 96]]

## God Nodes (most connected - your core abstractions)
1. `subscriber_1` - 23 edges
2. `Open5GS` - 8 edges
3. `slice_1` - 5 edges
4. `slice_2` - 5 edges
5. `slice_3` - 5 edges
6. `security` - 5 edges
7. `security` - 5 edges
8. `k8s-shell.sh script` - 4 edges
9. `Prometheus Custom Resource` - 4 edges
10. `sst` - 3 edges

## Surprising Connections (you probably didn't know these)
- `open5gs-amf` --implements--> `Open5GS`  [INFERRED]
  configs/open5gs/open5gs/common/amf/amf-deployment.yaml → README.md
- `kube-prometheus-stack` --conceptually_related_to--> `Open5GS`  [INFERRED]
  configs/prometheus/kube-prometheus-values-nuc.yaml → README.md
- `srsRAN UE1 Deployment` --semantically_similar_to--> `srsRAN gNB Deployment`  [INFERRED] [semantically similar]
  configs/ues/srsue/ue-deployment.yaml → configs/srsRAN/srsran-gnb/gnb-deployment.yaml
- `Node Resource Use Dashboard` --conceptually_related_to--> `Prometheus Custom Resource`  [INFERRED]
  configs/prometheus/kube-prometheus-stack/templates/grafana/dashboards-1.14/node-rsrc-use.yaml → configs/prometheus/kube-prometheus-stack/templates/prometheus/prometheus.yaml
- `Pod Total Dashboard` --references--> `K8s Recording Rules`  [INFERRED]
  configs/prometheus/kube-prometheus-stack/templates/grafana/dashboards-1.14/pod-total.yaml → configs/prometheus/kube-prometheus-stack/templates/prometheus/rules-1.14/k8s.rules.yaml

## Import Cycles
- None detected.

## Communities (97 total, 67 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (22): amf, k, op, opc, access_restriction_data, _id, imsi, network_access_mode (+14 more)

### Community 1 - "Community 1"
Cohesion: 0.10
Nodes (21): annotations, editable, fiscalYearStartMonth, graphTooltip, id, links, panels, refresh (+13 more)

### Community 2 - "Community 2"
Cohesion: 0.22
Nodes (4): Open5GS, Status, Type, Unit

### Community 3 - "Community 3"
Cohesion: 0.22
Nodes (8): deviceId, isPermanent, priority, selector, criteria, timeout, treatment, instructions

### Community 4 - "Community 4"
Cohesion: 0.22
Nodes (8): deviceId, isPermanent, priority, selector, criteria, timeout, treatment, instructions

### Community 5 - "Community 5"
Cohesion: 0.54
Nodes (7): slice_1, default_indicator, sd, session, sst, slice_2, slice_3

### Community 6 - "Community 6"
Cohesion: 0.33
Nodes (6): Node Resource Use Dashboard, Prometheus Cluster Role, Prometheus Custom Resource, Prometheus Scrape Config Secret, Prometheus Service, Prometheus Service Account

### Community 7 - "Community 7"
Cohesion: 0.40
Nodes (5): open5gs-amf, n2network, kube-prometheus-stack, Open5GS, srsRAN

### Community 8 - "Community 8"
Cohesion: 0.70
Nodes (4): select_container(), select_namespace(), usage(), k8s-shell.sh script

### Community 9 - "Community 9"
Cohesion: 0.60
Nodes (5): downlink, uplink, ambr, unit, value

### Community 10 - "Community 10"
Cohesion: 0.60
Nodes (5): downlink, uplink, ambr, unit, value

### Community 11 - "Community 11"
Cohesion: 0.40
Nodes (5): amf, k, op, opc, security

### Community 12 - "Community 12"
Cohesion: 0.60
Nodes (4): create_slices(), create_subscribers(), generate_slice_data(), generate_subscriber_data()

### Community 13 - "Community 13"
Cohesion: 0.50
Nodes (4): Alertmanager Overview Dashboard, API Server Dashboard, Grafana Namespace Template, Namespace by Pod Dashboard

### Community 14 - "Community 14"
Cohesion: 0.50
Nodes (4): AMF Service, NGAP Message, gNB Service, SCTP Association

### Community 15 - "Community 15"
Cohesion: 0.50
Nodes (4): Atomix Helm Chart, Bridge n3br, ONOS Classic Helm Chart, ONOS Config Loader

### Community 16 - "Community 16"
Cohesion: 0.50
Nodes (4): srsRAN gNB Deployment, gNB Service, srsRAN gNB Configuration, srsRAN UE1 Deployment

### Community 17 - "Community 17"
Cohesion: 0.50
Nodes (4): Grafana Test Pod, Grafana Test Role, Grafana Test RoleBinding, Grafana Test ServiceAccount

### Community 21 - "Community 21"
Cohesion: 0.67
Nodes (3): ServiceMonitor CRD, Kube State Metrics Service, Kube State Metrics ServiceMonitor

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (3): K8s Resources Pod Dashboard, K8s Resources Workload Dashboard, K8s Resources Workloads Namespace Dashboard

### Community 25 - "Community 25"
Cohesion: 0.67
Nodes (3): Open5GS AMF, MongoDB Service, Open5GS NRF

### Community 26 - "Community 26"
Cohesion: 0.67
Nodes (3): Logging System, Unreal Engine Logs Screenshot, Unreal Engine

## Knowledge Gaps
- **158 isolated node(s):** `connect_to_host.sh script`, `k8s-cpy.sh script`, `k8s-describe.sh script`, `k8s-exec.sh script`, `k8s-log.sh script` (+153 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **67 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `subscriber_1` connect `Community 0` to `Community 9`, `Community 10`, `Community 11`, `Community 1`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `schemaVersion` connect `Community 1` to `Community 0`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Open5GS` (e.g. with `list-subscribers.py` and `.add_subscriber()`) actually correct?**
  _`Open5GS` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `connect_to_host.sh script`, `k8s-cpy.sh script`, `k8s-describe.sh script` to the rest of the system?**
  _159 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._