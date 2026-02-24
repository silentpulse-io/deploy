# Graph Explorer

Interaktywna wizualizacja grafu encji i relacji w systemie.

## Cel

Umożliwia eksplorację grafu zależności między encjami (assety, grupy, typy obserwacji)
za pomocą dynamicznej wizualizacji force-directed z zapytaniami tekstowymi.

## Technologia

- **Sigma.js** — renderowanie grafu na canvasie (lekkie, wydajne)
- **Graphology** — struktura danych grafu w pamięci
- **ForceAtlas2** — algorytm layoutu force-directed (graphology-layout-forceatlas2)

### Poprzednia implementacja

ReactFlow + dagre (statyczny layout LR, renderowanie DOM).
Zastąpione ze względu na:
- Brak dynamicznego layoutu (dagre = statyczne pozycje)
- Ciężkie renderowanie DOM przy dużej liczbie węzłów
- Brak interaktywnych efektów hover

ReactFlow pozostaje w użyciu dla **pipeline editora** (edycja flow).

## Funkcjonalności

### Zapytania

Tekstowy język zapytań do filtrowania grafu:

| Składnia | Opis |
|----------|------|
| `type_slug` | Wszystkie encje danego typu |
| `type_slug[trait="value"]` | Filtrowanie po cechach |
| `type_a \| type_b` | Unia typów |
| `type_a -> type_b` | Traversal (relacje) |
| `type -> *` | Wszystkie połączone |
| `*` | Wszystko (z limitem) |

### Wizualizacja

- **ForceAtlas2 layout** — węzły rozmieszczane dynamicznie, grawitacja, odpychanie
- **Kolorowanie po typie** — każdy typ encji ma unikalny kolor z palety TYPE_COLORS
- **Hover highlighting** — powiększenie hovered węzła, podświetlenie sąsiadów, wygaszenie reszty
- **Strzałki na krawędziach** — kierunek relacji
- **Etykiety** — display_value na węzłach, relation_name na krawędziach

### Interakcja

- Kliknięcie węzła → panel boczny ze szczegółami (typ, display value, external_id, traits)
- Kliknięcie krawędzi → panel boczny (relacja, source, target)
- Kliknięcie tła → zamknięcie panelu
- Type chips → szybkie filtrowanie po typie
- Syntax help → podpowiedzi składni zapytań

## API

| Metoda | Endpoint               | Opis                                      |
|--------|------------------------|-------------------------------------------|
| POST   | /api/v1/graph/explore  | Eksploracja grafu (query + limit → nodes, edges, types) |

## Frontend

### Komponent

`components/graph/sigma-graph.tsx` — reużywalny komponent Sigma.js:
- Props: nodes, edges, types, onNodeClick, onEdgeClick, onBackgroundClick
- Tworzy Graphology Graph z losowymi pozycjami
- Uruchamia ForceAtlas2 (100 iteracji, barnesHutOptimize dla >50 węzłów)
- Tworzy instancję Sigma z canvas renderingiem
- Obsługuje hover effects i click events
- Cleanup na unmount (sigma.kill())

### Strona

`/dashboard/relationships` — query bar, type chips, syntax help, graf Sigma.js, panel boczny (node/edge details + type legend)

## Powiązania

- [dashboards.md](dashboards.md) — Graph Explorer jest częścią warstwy wizualnej
- [flows.md](flows.md) — Pipeline editor nadal używa ReactFlow
