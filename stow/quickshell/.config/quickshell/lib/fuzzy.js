.pragma library
// Subsequence fuzzy match (LAN device search; reusable for launchers).

// Score of `query` against `text`, or -1 for no match. "" matches everything.
// Consecutive characters and word starts score higher; shorter texts win ties.
function fuzzyScore(query, text) {
    query = query.toLowerCase();
    text = text.toLowerCase();
    if (query === "") return 1;
    let score = 0, ti = 0, streak = 0;
    for (let qi = 0; qi < query.length; qi++) {
        const idx = text.indexOf(query[qi], ti);
        if (idx === -1) return -1;
        if (idx === ti) {
            streak++;
            score += 2 + streak;          // consecutive chars
        } else {
            streak = 0;
            if (idx === 0 || /[^a-z0-9]/.test(text[idx - 1]))
                score += 4;               // word start
            else
                score += 1;
        }
        ti = idx + 1;
    }
    return score - text.length * 0.01;
}
