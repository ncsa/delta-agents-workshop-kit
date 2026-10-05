#!/usr/bin/env python3
"""Physics-informed neural network for the 1-D heat equation.

Solves u_t = alpha * u_xx on (0, 1) x (0, 0.5) with u(x, 0) = sin(pi x) and
u(0, t) = u(1, t) = 0. The network never sees the solution: its loss is the PDE
residual at random interior collocation points (computed by autograd) plus the
initial and boundary conditions. The analytic solution exp(-alpha pi^2 t) sin(pi x)
is used only afterwards, to measure the error honestly.

Log protocol (topics/LOG-PROTOCOL.md): `STEP n loss <l>` every --log-every steps,
`PROFILE <t> <x> <u_pred>` lines for the plot, then `L2_ERROR:` (relative L2 error on
a 101 x 51 grid), `PDE_RESIDUAL:` (RMS residual at fresh interior points),
`TRAIN_SECONDS:`, and `RESULTS_OK` last.

    python -u src/pinn.py --steps 8000 --n-colloc 2000 --alpha 0.05 --seed 1234
    python src/pinn.py --steps 200 --device cpu                    # smoke test
"""
import argparse
import math
import os
import sys
import time

import torch
import torch.nn as nn

T_END = 0.5


class MLP(nn.Module):
    """(x, t) -> u: `depth` hidden tanh layers of `width` units."""

    def __init__(self, width=32, depth=4):
        super().__init__()
        layers, d = [], 2
        for _ in range(depth):
            layers += [nn.Linear(d, width), nn.Tanh()]
            d = width
        layers.append(nn.Linear(d, 1))
        self.net = nn.Sequential(*layers)

    def forward(self, x, t):
        return self.net(torch.cat([x, t], dim=1))


def exact(x, t, alpha):
    return torch.exp(-alpha * math.pi ** 2 * t) * torch.sin(math.pi * x)


def residual(model, x, t, alpha):
    """u_t - alpha u_xx at (x, t); create_graph=True keeps the second derivative differentiable."""
    x = x.clone().requires_grad_(True)
    t = t.clone().requires_grad_(True)
    u = model(x, t)
    ones = torch.ones_like(u)
    u_x, u_t = torch.autograd.grad(u, (x, t), ones, create_graph=True)
    u_xx = torch.autograd.grad(u_x, x, torch.ones_like(u_x), create_graph=True)[0]
    return u_t - alpha * u_xx


def log(msg):
    print(msg, flush=True)


def pick_device(name):
    if name == "cpu":
        return torch.device("cpu")
    if not torch.cuda.is_available():
        if name == "cuda":
            raise SystemExit("no CUDA device visible: run inside a GPU job (keep --gpus-per-node=1), "
                             "or pass --device cpu")
        return torch.device("cpu")
    return torch.device("cuda")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--steps", type=int, default=8000, help="Adam steps")
    ap.add_argument("--lbfgs", type=int, default=0, help="L-BFGS iterations after Adam (0 = none; try 200)")
    ap.add_argument("--n-colloc", type=int, default=2000, help="interior collocation points")
    ap.add_argument("--n-ic", type=int, default=200, help="initial-condition points")
    ap.add_argument("--n-bc", type=int, default=200, help="boundary points (per side)")
    ap.add_argument("--alpha", type=float, default=0.05, help="diffusivity")
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--width", type=int, default=32)
    ap.add_argument("--depth", type=int, default=4)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--log-every", type=int, default=500)
    ap.add_argument("--device", choices=("cuda", "cpu", "auto"), default="cuda")
    ap.add_argument("--threads", type=int, default=0, help="torch CPU threads (0 = torch default)")
    args = ap.parse_args()

    if args.threads > 0:
        torch.set_num_threads(args.threads)
    torch.manual_seed(args.seed)
    dev = pick_device(args.device)
    gpu = torch.cuda.get_device_name(dev) if dev.type == "cuda" else "none"
    log(f"[pinn] host={os.uname().nodename} device={dev} gpu={gpu} torch={torch.__version__} "
        f"steps={args.steps} lbfgs={args.lbfgs} n_colloc={args.n_colloc} alpha={args.alpha} seed={args.seed}")

    g = torch.Generator().manual_seed(args.seed)

    def rand(n):
        return torch.rand(n, 1, generator=g)

    # Collocation points are sampled once, strictly inside the domain (not on the boundary).
    eps = 1e-3
    xc = (eps + (1 - 2 * eps) * rand(args.n_colloc)).to(dev)
    tc = (eps + (T_END - eps) * rand(args.n_colloc)).to(dev)
    x0 = rand(args.n_ic).to(dev)
    t0 = torch.zeros_like(x0)
    tb = (T_END * rand(args.n_bc)).to(dev)
    xb = torch.cat([torch.zeros_like(tb), torch.ones_like(tb)])
    tb = torch.cat([tb, tb])

    model = MLP(args.width, args.depth).to(dev)

    def loss_fn():
        r = residual(model, xc, tc, args.alpha)
        ic = model(x0, t0) - torch.sin(math.pi * x0)
        bc = model(xb, tb)
        return (r ** 2).mean() + (ic ** 2).mean() + (bc ** 2).mean()

    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    if dev.type == "cuda":
        torch.cuda.synchronize()
    start = time.perf_counter()
    loss = None
    for step in range(args.steps + 1):
        opt.zero_grad(set_to_none=True)
        loss = loss_fn()
        if step % args.log_every == 0 or step == args.steps:
            log(f"STEP {step} loss {loss.item():.6e}")
        if step == args.steps:
            break
        loss.backward()
        opt.step()

    if args.lbfgs > 0:
        lb = torch.optim.LBFGS(model.parameters(), lr=1.0, max_iter=args.lbfgs,
                               history_size=50, line_search_fn="strong_wolfe")

        def closure():
            lb.zero_grad(set_to_none=True)
            value = loss_fn()
            value.backward()
            return value

        lb.step(closure)
        loss = loss_fn()
        log(f"STEP {args.steps + args.lbfgs} loss {loss.item():.6e}")
    if dev.type == "cuda":
        torch.cuda.synchronize()
    train_seconds = time.perf_counter() - start

    # Error against the analytic solution on a regular grid (never used in training).
    xs = torch.linspace(0, 1, 101, device=dev)
    ts = torch.linspace(0, T_END, 51, device=dev)
    X, T = torch.meshgrid(xs, ts, indexing="ij")
    X, T = X.reshape(-1, 1), T.reshape(-1, 1)
    with torch.no_grad():
        u = model(X, T)
    ue = exact(X, T, args.alpha)
    l2 = (torch.linalg.vector_norm(u - ue) / torch.linalg.vector_norm(ue)).item()

    xr = (eps + (1 - 2 * eps) * rand(4000)).to(dev)
    tr = (eps + (T_END - eps) * rand(4000)).to(dev)
    pde = residual(model, xr, tr, args.alpha).pow(2).mean().sqrt().item()

    with torch.no_grad():
        for tval in (0.25, 0.5):
            xp = torch.linspace(0, 1, 21, device=dev).reshape(-1, 1)
            up = model(xp, torch.full_like(xp, tval))
            for xv, uv in zip(xp.flatten().tolist(), up.flatten().tolist()):
                log(f"PROFILE {tval:.2f} {xv:.3f} {uv:.6f}")

    log(f"FINAL_LOSS: {loss.item():.6e}")
    log(f"L2_ERROR: {l2:.4e}")
    log(f"PDE_RESIDUAL: {pde:.4e}")
    log(f"TRAIN_SECONDS: {train_seconds:.2f}")
    log("RESULTS_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
