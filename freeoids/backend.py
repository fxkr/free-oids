import datetime
import io
import flask
import csv

import flask

from freeoids import util


class BackendError(Exception):
    pass


def assign_oid(comment="", prefix_str=None, path=None):
    prefix_str = prefix_str or flask.current_app.config['ASSIGNMENT_PREFIX']
    path = path or flask.current_app.config['ASSIGNMENT_FILE']

    prefix = tuple(int(num_str) for num_str in prefix_str.split("."))

    next_free_node = 0
    most_recent_assignment = None

    with open(path, 'ab') as wf, util.fsyncing(wf), util.flocking(wf), util.flushing(wf),\
         open(path, 'rb') as rf:

        csv_reader = csv.reader(rf, delimiter='\t')
        for i, (assigned_date_str, assigned_prefix_str, assigned_comment_str) in enumerate(csv_reader):
            assigned_prefix = tuple(int(num) for num in assigned_prefix_str.split("."))

            if prefix != assigned_prefix[:len(prefix)]:
                raise BackendError("line %i: assignment of other prefix: %s" % (i, assigned_prefix_str))
            elif len(prefix) >= len(assigned_prefix):
                raise BackendError("line %i: assignment of our entire prefix: %s" % (i, assigned_prefix_str))

            assigned_node = assigned_prefix[-1]
            if assigned_node >= next_free_node:
                next_free_node = assigned_node + 1

        newly_assigned_prefix = prefix + (next_free_node,)
        newly_assigned_prefix_str = ".".join(str(num) for num in newly_assigned_prefix)

        wf.seek(0, io.SEEK_END)
        csv_writer = csv.writer(wf, delimiter="\t", lineterminator="\n")
        csv_writer.writerow([
            datetime.datetime.now().isoformat().encode("utf-8"),
            newly_assigned_prefix_str.encode("utf-8"),
            comment.strip().encode("utf-8")
        ])

    return newly_assigned_prefix_str

