# 🛸 OrbitGuard v3 — Satellite Collision Avoidance System

A complete, production-grade satellite collision avoidance system with live TLE data, full simulation reports, 3D orbit visualization, and maneuver planning.

---

## 🚀 Quick Start

### Option A — Docker (one command)
```bash
unzip orbitguard.zip && cd orbitguard
docker compose up --build
```
- **Frontend**: http://localhost:3000
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

### Option B — Manual
```bash
# Backend (Terminal 1)
cd orbitguard/backend
pip install -r requirements.txt
uvicorn api.main:app --reload --port 8000

# Frontend (Terminal 2) — just open the file or serve it:
cd orbitguard/frontend
python -m http.server 3000
# Then open http://localhost:3000
```

### Demo only (no server)
```bash
cd orbitguard/backend
pip install numpy scipy
python3 -c "
from core.simulation import *
primary = keplerian_to_state(R_EARTH+550000, 0.001, 53, 0, 0, 0)
debris = sim_engine.generate_synthetic_debris(primary, 8)
cfg = SimulationConfig('MY-SAT', duration_hours=12)
r = sim_engine.run(cfg, debris)
print(f'Conjunctions: {len(r.conjunctions)}, Maneuver needed: {r.maneuver_needed}')
for c in r.conjunctions[:3]:
    c = c if isinstance(c, dict) else c
    print(f'  {c[\"debris_name\"]}: miss={c[\"miss_distance_km\"]}km Pc={c[\"pc_scientific\"]} risk={c[\"risk_level\"]}')
"
```

---

## 🏗 Architecture

```
orbitguard/
├── backend/
│   ├── api/main.py              FastAPI REST + WebSocket
│   ├── core/simulation.py       Full simulation engine
│   │   ├── RK4+J2 propagator
│   │   ├── Conjunction detection
│   │   ├── Chan Pc computation
│   │   └── 6-strategy maneuver optimizer
│   └── services/tle_service.py  Live TLE from CelesTrak
├── frontend/
│   └── index.html               Complete single-file React-like UI
│       ├── Dashboard
│       ├── Simulation runner
│       ├── Full report view
│       ├── 3D globe (Three.js)
│       ├── Quick conjunction tool
│       ├── Maneuver planner
│       └── TLE catalog browser
└── docker-compose.yml
```

---

## 🔬 Algorithms

### Orbital Propagator
- **RK4 + J2 oblateness** — 4th-order Runge-Kutta with J2 zonal harmonic
- Step size: 15s (simulation), 60s (optimizer)
- Handles retrograde orbits, eccentric orbits, all inclinations

### Conjunction Detection
- Per-debris trajectory comparison at 500 time steps
- Miss distance = minimum of ||r_primary - r_debris||
- Filters by screening distance (default 10 km)

### Collision Probability (Chan 1997)
```
Pc = (R_hb / σ_pos)² × exp(-0.5 × (miss/σ_pos)²)
```
- R_hb = hard-body radius (10 m default)
- σ_pos = position uncertainty (200 m default — typical TLE 1σ)

### Risk Thresholds
| Level | Pc | ESA/NASA threshold |
|---|---|---|
| CRITICAL | > 10⁻³ | Immediate maneuver |
| HIGH | > 10⁻⁴ | Maneuver recommended |
| MEDIUM | > 10⁻⁵ | Monitor closely |
| LOW | ≤ 10⁻⁵ | Routine tracking |

### Maneuver Optimizer
6 directions evaluated: ±Radial, ±Prograde, ±Normal

For each direction:
1. Binary search (8 iterations) for minimum ΔV achieving 5 km miss
2. Fuel via Tsiolkovsky: `Δm = m_dry × (exp(ΔV / (Isp × g₀)) - 1)`
3. Efficiency score = post-miss(km) / ΔV(m/s) — higher is better
4. Sorted by efficiency

### TLE Live Data
- Source: CelesTrak `catalog.txt` (public, free, updated multiple times daily)
- Falls back to 8 embedded well-known objects if offline
- Auto-screens objects with similar altitude (±60 km) and inclination (±30°)

---

## 🌐 API Reference

| Endpoint | Method | Description |
|---|---|---|
| `/api/health` | GET | Health check + TLE count |
| `/api/stats` | GET | Catalog statistics |
| `/api/simulate` | POST | **Full simulation** → complete report |
| `/api/conjunction` | POST | Quick 2-object conjunction analysis |
| `/api/maneuver` | POST | Maneuver optimization |
| `/api/demo` | GET | Pre-run demo scenario |
| `/api/tle/search` | GET | Search TLE catalog |
| `/api/tle/{norad_id}` | GET | Get specific object |
| `/api/tle/refresh` | GET | Trigger live TLE refresh |
| `/api/tle/debris/leo` | GET | List LEO debris |
| `/api/tle/parse` | POST | Parse custom TLE |
| `/api/reports` | GET | List stored reports |
| `/api/reports/{id}` | GET | Get stored report |
| `/ws` | WS | Real-time WebSocket |

### Simulation Request Body
```json
{
  "satellite_name": "MY-SAT-1",
  "elements": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "duration_hours": 24,
  "max_dv_ms": 5.0,
  "satellite_mass_kg": 300,
  "satellite_isp_s": 220,
  "screening_distance_km": 10,
  "use_live_tle": true,
  "use_synthetic": false
}
```

### Quick Conjunction (Primary + Secondary) — copy/paste input
Use this when you have **two objects** (e.g., your satellite and a specific debris object) and you want the miss distance, TCA, Pc, and risk quickly.

```json
{
  "primary": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "secondary": {
    "altitude_km": 550,
    "inclination_deg": 127,
    "eccentricity": 0.02,
    "raan_deg": 40,
    "argp_deg": 10,
    "true_anomaly_deg": 180
  },
  "duration_hours": 24
}
```

### Maneuver Planner (Primary + Debris + TCA) — copy/paste input
Use this when you already have a suspected conjunction and want **maneuver plans** (6 RTN directions) and a recommended burn.

```json
{
  "primary": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "debris": {
    "altitude_km": 550,
    "inclination_deg": 127,
    "eccentricity": 0.02,
    "raan_deg": 40,
    "argp_deg": 10,
    "true_anomaly_deg": 180
  },
  "tca_hours": 6,
  "duration_hours": 24,
  "max_dv_ms": 5,
  "satellite_mass_kg": 300,
  "isp_s": 220
}
```

### Guaranteed Collision Demo (Full Simulation) — copy/paste input
If you want to **force a collision** (so you can see `collision_detected: true` in the simulation output), set `force_collision_demo: true`.

```json
{
  "satellite_name": "COLLISION-DEMO-SAT",
  "elements": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "duration_hours": 6,
  "screening_distance_km": 10,
  "max_dv_ms": 5,
  "satellite_mass_kg": 300,
  "satellite_isp_s": 220,
  "use_live_tle": false,
  "use_synthetic": false,
  "force_collision_demo": true
}
```

### Guaranteed Collision Demo (Quick Conjunction) — copy/paste input
For the quick tool, using **identical elements** produces a \(0\) miss distance and shows an extreme-risk case:

```json
{
  "primary": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "secondary": {
    "altitude_km": 550,
    "inclination_deg": 53,
    "eccentricity": 0.001,
    "raan_deg": 0,
    "argp_deg": 0,
    "true_anomaly_deg": 0
  },
  "duration_hours": 6
}
```

Or with TLE:
```json
{
  "satellite_name": "ISS",
  "tle": {
    "name": "ISS (ZARYA)",
    "line1": "1 25544U 98067A ...",
    "line2": "2 25544 ..."
  },
  "duration_hours": 24
}
```

---

## 🖥 Frontend Pages

| Page | Features |
|---|---|
| **Dashboard** | Stats, how-it-works, recent reports |
| **Run Simulation** | Orbital elements or TLE input, debris source config, real-time progress |
| **Simulation Report** | Full report: risk summary, conjunction table, distance charts, maneuver plans, orbital state data |
| **3D Orbit View** | Three.js globe, animated satellite + debris orbits, drag/zoom |
| **Quick Conjunction** | Fast 2-object analysis with chart |
| **Maneuver Planner** | 6-strategy maneuver comparison |
| **TLE Catalog** | Search and browse live catalog |

---

## 📋 Simulation Report Contents

Each simulation generates a complete JSON report containing:
- Primary satellite orbital state (ECI + Keplerian)
- All conjunction events with: object name, NORAD ID, TCA, miss distance, relative velocity, Pc, risk level
- Distance vs time timeline for each conjunction
- Debris orbital state at TCA
- All 6 maneuver plans (if needed) with ΔV, direction, fuel cost, post-maneuver miss, efficiency
- Recommended maneuver
- Primary and debris ECI trajectories (lat/lon/alt)
- Simulation metadata

---

## 🛠 Configuration

All parameters tunable via the UI or API:
- **Duration**: 1–72 hours
- **Max ΔV**: 0.1–50 m/s
- **Satellite mass**: 1–10,000 kg
- **Isp**: 50–500 s (affects fuel calculation)
- **Screening distance**: 1–100 km
- **Hard body radius**: 10 m (can be changed in `simulation.py`)
- **Position uncertainty σ**: 200 m (can be changed in `simulation.py`)
