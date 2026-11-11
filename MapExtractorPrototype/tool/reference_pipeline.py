"""Reference pipeline for the Battletech map extractor.

This file mirrors the Dart implementation in lib/src/extract step by step,
so you can compare intermediate values when the two disagree. It uses cv2
only for image decoding, resizing and connected components. Everything
else is plain numpy.

Usage:
  pip install onnxruntime opencv-python numpy
  python3 tool/reference_pipeline.py OUT.json IMAGE [IMAGE ...]

Environment:
  MODEL_DIR   folder with the ONNX models (default: assets/models)
  ASCII_ONLY  1 (default) masks non-ASCII recognizer classes before argmax
"""
import json
import math
import os
import re
import sys
import time

import cv2
import numpy as np
import onnxruntime as ort

# ---------------------------------------------------------------- constants
TILE = 1408            # multiple of 32, so full tiles need no det resize
TILE_OVERLAP = 160
DET_LIMIT_MIN_SIDE = 736
DET_THRESH = 0.3
DET_BOX_THRESH = 0.5
DET_UNCLIP = 1.6
DET_MIN_SIZE = 3
REC_H = 48
REC_MIN_W = 320
TEXT_SCORE = 0.5
EDGE_MARGIN = 4        # px: drop boxes that touch an inner tile edge
RANSAC_ITERS = 1000
RANSAC_THRESH = 6.0
LABEL_ROW_OFFSET = 0.8  # a label sits 0.8 row below its own hex number


# ---------------------------------------------------------------- OCR
class PaddleOcr:
    def __init__(self, det_path, rec_path, dict_path, ascii_only=True):
        self.det = ort.InferenceSession(det_path)
        self.rec = ort.InferenceSession(rec_path)
        chars = open(dict_path, encoding="utf-8").read().split("\n")
        if chars and chars[-1] == "":
            chars = chars[:-1]
        # index 0 is the CTC blank, then the dictionary, then a space
        self.charset = ["<blank>"] + chars + [" "]
        self.allowed = np.zeros(len(self.charset), bool)
        self.allowed[0] = True
        for i, c in enumerate(self.charset):
            if c == " " or (len(c) == 1 and c.isascii() and (c.isalnum() or c in "-|")):
                self.allowed[i] = True
        self.ascii_only = ascii_only

    def detect(self, img):
        """BGR uint8 HxWx3 -> list of (x0, y0, x1, y1, score) in img pixels."""
        h, w = img.shape[:2]
        ratio = 1.0
        if min(h, w) < DET_LIMIT_MIN_SIDE:
            ratio = DET_LIMIT_MIN_SIDE / min(h, w)
        rh = max(32, int(round(int(h * ratio) / 32) * 32))
        rw = max(32, int(round(int(w * ratio) / 32) * 32))
        x = img if (rh, rw) == (h, w) else cv2.resize(img, (rw, rh), interpolation=cv2.INTER_LINEAR)
        x = (x.astype(np.float32) / 255.0 - 0.5) / 0.5
        x = x.transpose(2, 0, 1)[None]
        pred = self.det.run(None, {"x": x})[0][0, 0]
        mask = (pred > DET_THRESH).astype(np.uint8)
        # 2x2 dilation, anchor (1,1): out(y,x) = max(in[y-1..y, x-1..x])
        d = mask.copy()
        d[1:, :] |= mask[:-1, :]
        d[:, 1:] |= mask[:, :-1]
        d[1:, 1:] |= mask[:-1, :-1]
        n, _, stats, _ = cv2.connectedComponentsWithStats(d, connectivity=8)
        boxes = []
        ph, pw = pred.shape
        for k in range(1, n):
            x0, y0, bw, bh, _ = stats[k]
            x1, y1 = x0 + bw - 1, y0 + bh - 1      # pixel-centre extents
            if min(x1 - x0, y1 - y0) < DET_MIN_SIZE:
                continue
            score = float(pred[y0:y1 + 1, x0:x1 + 1].mean())
            if score < DET_BOX_THRESH:
                continue
            ew, eh = x1 - x0, y1 - y0
            dist = ew * eh * DET_UNCLIP / (2 * (ew + eh))
            ux0, uy0, ux1, uy1 = x0 - dist, y0 - dist, x1 + dist, y1 + dist
            if min(ux1 - ux0, uy1 - uy0) < DET_MIN_SIZE + 2:
                continue
            sx, sy = w / pw, h / ph
            bx0 = int(np.clip(round(ux0 * sx), 0, w)); bx1 = int(np.clip(round(ux1 * sx), 0, w))
            by0 = int(np.clip(round(uy0 * sy), 0, h)); by1 = int(np.clip(round(uy1 * sy), 0, h))
            boxes.append((bx0, by0, bx1, by1, score))
        return boxes

    def recognize(self, crop):
        """BGR crop -> (text, mean char conf, min char conf), greedy CTC decoding."""
        h, w = crop.shape[:2]
        ratio = w / h
        img_w = int(REC_H * max(REC_MIN_W / REC_H, ratio))
        rw = min(img_w, int(math.ceil(REC_H * ratio)))
        r = cv2.resize(crop, (rw, REC_H), interpolation=cv2.INTER_LINEAR).astype(np.float32)
        r = (r / 255.0 - 0.5) / 0.5
        x = np.zeros((1, 3, REC_H, img_w), np.float32)
        x[0, :, :, :rw] = r.transpose(2, 0, 1)
        probs = self.rec.run(None, {"x": x})[0][0]           # T x C
        if self.ascii_only:
            probs = np.where(self.allowed[None, :], probs, 0.0)
        idx = probs.argmax(1)
        conf = probs.max(1)
        text, confs, prev = [], [], -1
        for t, i in enumerate(idx):
            if i != 0 and i != prev:
                text.append(self.charset[i]); confs.append(conf[t])
            prev = i
        if not confs:
            return "", 0.0, 0.0
        return "".join(text), float(np.mean(confs)), float(np.min(confs))

    def read(self, img):
        """Tile, detect, recognise. Returns [(x0, y0, x1, y1, text, score, min_conf)]."""
        H, W = img.shape[:2]

        def starts(n):
            if n <= TILE:
                return [0]
            s = list(range(0, n - TILE, TILE - TILE_OVERLAP))
            s.append(n - TILE)
            return s

        out = []
        for ty in starts(H):
            for tx in starts(W):
                tile = img[ty:ty + TILE, tx:tx + TILE]
                th, tw = tile.shape[:2]
                for x0, y0, x1, y1, _ in self.detect(tile):
                    # drop boxes cut by an inner tile edge: the neighbour tile sees them whole
                    if (tx > 0 and x0 <= EDGE_MARGIN) or (ty > 0 and y0 <= EDGE_MARGIN) \
                       or (tx + tw < W and x1 >= tw - EDGE_MARGIN) \
                       or (ty + th < H and y1 >= th - EDGE_MARGIN):
                        continue
                    bw, bh = x1 - x0, y1 - y0
                    if bw < 2 or bh < 2 or bh / bw >= 1.5:
                        continue
                    text, score, min_conf = self.recognize(tile[y0:y1, x0:x1])
                    if score >= TEXT_SCORE and text.strip():
                        out.append((tx + x0, ty + y0, tx + x1, ty + y1, text.strip(), score, min_conf))
        return out


# ---------------------------------------------------------------- parsing
WORDS = ["LIGHT", "HEAVY", "ULTRA", "ROUGH", "RUBBLE", "LEVEL", "DEPTH", "WATER",
         "BUILDING", "PAVEMENT", "PAVED", "ROAD", "SWAMP", "SAND", "ICE", "BRIDGE"]
NUMBERED = ("LEVEL", "DEPTH")
DIGIT_FIX = {"I": "1", "L": "1", "T": "1", "|": "1", "Z": "2", "S": "5", "O": "0", "B": "8", "G": "6"}
ID_FIX = {"O": "0", "D": "0", "I": "1", "L": "1", "|": "1", "Z": "2", "S": "5", "B": "8"}


def similarity(a, b):
    """Levenshtein ratio: 1 - distance / max(len)."""
    if not a and not b:
        return 1.0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return 1.0 - prev[-1] / max(len(a), len(b))


def parse_hex_id(text, max_col=99, max_row=99):
    t = re.sub(r"\s", "", text.upper())
    if len(t) != 4:
        return None
    t = "".join(ID_FIX.get(c, c) for c in t)
    if not t.isdigit():
        return None
    c, r = int(t[:2]), int(t[2:])
    if 1 <= c <= max_col and 1 <= r <= max_row:
        return c, r
    return None


def parse_label(text):
    """Return [(token, certain)], token like 'LIGHT', 'LEVEL 2', 'LEVEL ?'.

    certain is False when the number came from a letter substitution
    (for example B -> 8), is missing, or is negative. The editor asks the
    user to review those hexes instead of trusting the guess.
    """
    compact = re.sub(r"[^A-Z0-9|\-]", "", text.upper())
    for word in WORDS:
        for n in (len(word), len(word) - 1, len(word) + 1):
            head, tail = compact[:n], compact[n:]
            if len(head) < 3:
                continue
            if similarity(head, word) >= 0.8:
                if word not in NUMBERED:
                    return [(word, True)]
                neg = tail.startswith("-")
                tail = tail.lstrip("-")
                ch = tail[:1]
                if ch.isdigit():
                    return [(f"{word} {'-' if neg else ''}{ch}", not neg)]
                if ch in DIGIT_FIX:
                    return [(f"{word} {'-' if neg else ''}{DIGIT_FIX[ch]}", False)]
                return [(f"{word} ?", False)]
    return []


# ---------------------------------------------------------------- geometry
def grid_point(c, r):
    """Grid space: x = column, y = row, even columns shifted down half a row."""
    return (float(c), r + (0.5 if c % 2 == 0 else 0.0))


def _normalizer(pts):
    m = pts.mean(0)
    s = math.sqrt(2) / max(1e-9, np.sqrt(((pts - m) ** 2).sum(1)).mean())
    return np.array([[s, 0, -s * m[0]], [0, s, -s * m[1]], [0, 0, 1]])


def solve_linear(A, b):
    """Gauss-Jordan elimination with partial pivoting (same as Dart)."""
    n = len(b)
    M = np.hstack([A.astype(float), b.reshape(-1, 1).astype(float)])
    for col in range(n):
        piv = col + int(np.argmax(np.abs(M[col:, col])))
        if abs(M[piv, col]) < 1e-12:
            return None
        M[[col, piv]] = M[[piv, col]]
        M[col] /= M[col, col]
        for row in range(n):
            if row != col:
                M[row] -= M[row, col] * M[col]
    return M[:, n]


def fit_homography(src, dst):
    """Least-squares DLT with h33 = 1, after Hartley normalisation."""
    src = np.asarray(src, float); dst = np.asarray(dst, float)
    Ts, Td = _normalizer(src), _normalizer(dst)
    s = (np.c_[src, np.ones(len(src))] @ Ts.T)[:, :2]
    d = (np.c_[dst, np.ones(len(dst))] @ Td.T)[:, :2]
    A, b = [], []
    for (x, y), (u, v) in zip(s, d):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    A = np.array(A); b = np.array(b)
    h = solve_linear(A.T @ A, A.T @ b)
    if h is None:
        return None
    H = np.linalg.inv(Td) @ np.append(h, 1.0).reshape(3, 3) @ Ts
    return H / H[2, 2]


def project(H, pts):
    p = np.c_[np.asarray(pts, float), np.ones(len(pts))] @ H.T
    return p[:, :2] / p[:, 2:3]


class Lcg:
    """Small deterministic RNG, identical in Dart."""
    def __init__(self, seed=12345):
        self.s = seed

    def next_int(self, n):
        self.s = (self.s * 1103515245 + 12345) & 0x7FFFFFFF
        return self.s % n


def ransac_homography(src, dst):
    n = len(src)
    if n < 4:
        return None, np.zeros(n, bool)
    src = np.asarray(src, float); dst = np.asarray(dst, float)
    rng = Lcg()
    best, best_count = None, 0
    for _ in range(RANSAC_ITERS):
        idx = set()
        while len(idx) < 4:
            idx.add(rng.next_int(n))
        idx = sorted(idx)
        H = fit_homography(src[idx], dst[idx])
        if H is None:
            continue
        inl = np.linalg.norm(project(H, src) - dst, axis=1) < RANSAC_THRESH
        if inl.sum() > best_count:
            best_count, best = int(inl.sum()), inl
    if best is None:
        return None, np.zeros(n, bool)
    inl = best
    H = None
    for _ in range(2):
        H = fit_homography(src[inl], dst[inl])
        inl = np.linalg.norm(project(H, src) - dst, axis=1) < RANSAC_THRESH
    return H, inl


# ---------------------------------------------------------------- per image
def rotate(img, quarter_turns_cw):
    k = quarter_turns_cw % 4
    if k == 1:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    if k == 2:
        return cv2.rotate(img, cv2.ROTATE_180)
    if k == 3:
        return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return img


def probe_rotation(ocr, img):
    """Read the centre tile at each quarter turn, keep the one with most hex ids."""
    best = (0, -1)
    for k in range(4):
        r = rotate(img, k)
        h, w = r.shape[:2]
        y0, x0 = max(0, h // 2 - TILE // 2), max(0, w // 2 - TILE // 2)
        tile = r[y0:y0 + TILE, x0:x0 + TILE]
        count = sum(1 for w in ocr.read(tile) if parse_hex_id(w[4]))
        if count > best[1]:
            best = (k, count)
    return best


def extract_image(ocr, img):
    t0 = time.time()
    k, probe = probe_rotation(ocr, img)
    img = rotate(img, k)
    words = ocr.read(img)
    anchors, others = {}, []
    for x0, y0, x1, y1, text, score, min_conf in words:
        cr = parse_hex_id(text)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        if cr:
            anchors.setdefault(cr, (cx, cy, score))
        else:
            others.append((cx, cy, text, min_conf))
    keys = list(anchors)
    src = [grid_point(*key) for key in keys]
    dst = [anchors[key][:2] for key in keys]
    Hm, inl = ransac_homography(src, dst)
    if Hm is None:
        return None
    inv = np.linalg.inv(Hm)
    res = np.linalg.norm(project(Hm, np.array(src)[inl]) - np.array(dst)[inl], axis=1)
    inlier_ids = [keys[i] for i in range(len(keys)) if inl[i]]
    labels = {}
    for cx, cy, text, score in others:
        toks = parse_label(text)
        if not toks:
            continue
        u, v = project(inv, [(cx, cy)])[0]
        c = int(round(u))
        r = int(round(v - (0.5 if c % 2 == 0 else 0.0) - LABEL_ROW_OFFSET))
        if c < 1 or r < 1:
            continue
        for tok, certain in toks:
            labels.setdefault((c, r), []).append((tok, score, text, certain))
    return {
        "rotation": k, "probe": probe, "anchors": len(keys), "inliers": int(inl.sum()),
        "resid": float(np.median(res)), "cols": max(c for c, _ in inlier_ids),
        "rows": max(r for _, r in inlier_ids), "labels": labels, "H": Hm,
        "secs": time.time() - t0,
    }


def merge(results):
    """Vote per hex across images.

    Each token gets the sum of its scores, halved for uncertain readings.
    Each slot (LEVEL, DEPTH, or a plain word) keeps its best token. A hex
    needs review when its winning token was never read with certainty or
    when another token for the same slot also got votes.
    Returns {hexid: {"tokens": [...], "review": bool}}.
    """
    votes = {}
    for res in results:
        for (c, r), toks in res["labels"].items():
            best = {}
            for tok, score, _, certain in toks:   # one vote per token per image
                w = score if certain else 0.5 * score
                if tok not in best or w > best[tok][0]:
                    best[tok] = (w, certain)
            for tok, (w, certain) in best.items():
                v = votes.setdefault((c, r), {}).setdefault(tok, [0.0, False])
                v[0] += w
                v[1] = v[1] or certain
    out = {}
    for (c, r), v in votes.items():
        slots = {}
        for tok, (w, certain) in v.items():
            slots.setdefault(tok.split()[0], []).append((w, tok, certain))
        tokens, review = [], False
        for word, cands in slots.items():
            known = [x for x in cands if not x[1].endswith("?")] or cands
            known.sort(reverse=True)
            w, tok, certain = known[0]
            tokens.append(tok)
            if not certain or len(known) > 1:
                review = True
        out[f"{c:02d}{r:02d}"] = {"tokens": sorted(tokens), "review": review}
    return out


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    model_dir = os.environ.get("MODEL_DIR", os.path.join(here, "..", "assets", "models"))
    ocr = PaddleOcr(os.path.join(model_dir, "ppocrv4_det.onnx"),
                    os.path.join(model_dir, "ppocrv4_rec.onnx"),
                    os.path.join(model_dir, "ppocrv4_rec_dict.txt"),
                    ascii_only=os.environ.get("ASCII_ONLY", "1") == "1")
    results = []
    for p in sys.argv[2:]:
        img = cv2.imread(p, cv2.IMREAD_COLOR)  # applies EXIF orientation
        r = extract_image(ocr, img)
        print(f"{os.path.basename(p)}: rot={r['rotation'] * 90} probe={r['probe']} ids={r['anchors']} "
              f"inliers={r['inliers']} resid={r['resid']:.1f}px size={r['cols']}x{r['rows']} "
              f"labelled={len(r['labels'])} {r['secs']:.0f}s", flush=True)
        results.append(r)
    json.dump(merge(results), open(sys.argv[1], "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
