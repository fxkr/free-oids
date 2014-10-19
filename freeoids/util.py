import contextlib
import fcntl
import os


@contextlib.contextmanager
def flocking(file):
    fcntl.lockf(file.fileno(), fcntl.LOCK_EX)
    try:
        yield
    finally:
        fcntl.lockf(file.fileno(), fcntl.LOCK_UN)


@contextlib.contextmanager
def flushing(file):
    try:
        yield
    finally:
        file.flush()


@contextlib.contextmanager
def fsyncing(file):
    try:
        yield
    finally:
        os.fsync(file.fileno())

