import numpy as np
import pytest

from predaudit import grading
from predaudit.backends.toy import ToyBackend
from predaudit.stats import confusion, wilson


def test_graders():
    tr = np.array([0, 1, 1, 0, 1, 1, 1, 0], dtype=bool)
    assert grading.first_hit(tr)
    assert not grading.end_of_episode(tr)
    assert grading.persistent(tr, 3)
    assert not grading.persistent(tr, 4)
    assert not grading.persistent(tr, 3, extra=[1, 1, 1, 1, 1, 0, 1, 1])
    assert not grading.first_hit(np.zeros(5, dtype=bool))
    with pytest.raises(ValueError):
        grading.persistent(tr, 0)


def test_wilson():
    lo, hi = wilson(5, 100)
    assert lo == pytest.approx(0.0215, abs=1e-3)
    assert hi == pytest.approx(0.1118, abs=1e-3)
    assert wilson(0, 0) == (0.0, 1.0)


def test_confusion():
    c = confusion([1, 1, 1, 0, 0], [1, 0, 1, 1, 0])
    assert (c["tp"], c["fp"], c["fn"], c["tn"]) == (2, 1, 1, 1)
    assert c["false_success_rate"]["rate"] == pytest.approx(1 / 3)
    assert c["false_failure_rate"]["rate"] == pytest.approx(1 / 2)


def test_toy_backend_is_deterministic_and_shows_transients():
    b = ToyBackend()
    a = b.rollout("toy_put_in_bin", "weak", 3)
    assert np.array_equal(a.trace, b.rollout("toy_put_in_bin", "weak", 3).trace)
    eps = [b.rollout("toy_put_in_bin", "weak", s) for s in range(300)]
    builtin = [grading.first_hit(e.trace) for e in eps]
    strict = [grading.persistent(e.trace, 100) for e in eps]
    ref = [e.reference for e in eps]
    fs_builtin = confusion(builtin, ref)["false_success_rate"]["rate"]
    fs_strict = confusion(strict, ref)["false_success_rate"]["rate"]
    assert fs_builtin > 0.05
    assert fs_strict < fs_builtin
