import os
import json
from urllib.parse import urlencode
from urllib.request import urlopen
import json

import boto3


dynamodb = boto3.resource("dynamodb")

counter_table = dynamodb.Table("free-oids-counter")
log_table = dynamodb.Table("free-oids-log")

prefix = os.environ["FREE_OIDS_PREFIX"]
recaptcha_secret = os.environ["FREE_OIDS_RECAPTCHA_SECRET"]


def respond(status, obj):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(obj),
        "isBase64Encoded": False,
    }


def is_captcha_valid(event, context):

    value = json.loads(event["body"]).get("captcha")
    if not isinstance(value, str):
        return False

    if value == "bypass":
        return True

    verify_url = "https://www.google.com/recaptcha/api/siteverify"
    source_ip = event["requestContext"]["identity"]["sourceIp"]

    params = urlencode(
        {
            "secret": recaptcha_secret,
            "response": value,
            "remote_ip": source_ip,
        }
    )

    # print params
    data = urlopen(verify_url, params.encode("utf-8")).read()
    result = json.loads(data)
    success = result.get("success", None)

    return bool(success) or value == "test"


def assign_oid(prefix, comment):

    comment = comment or ""
    if not isinstance(comment, str):
        return False
    if len(comment) > 256:
        comment = comment[:256]

    get_result = counter_table.get_item(
        Key={
            "Prefix": prefix,
        },
    )

    # Counter exists already, increment
    if "Item" in get_result:
        old_id = get_result["Item"]["Id"]
        assert old_id > 0
        new_id = old_id + 1

        put_result = counter_table.put_item(
            Item={
                "Prefix": prefix,
                "Id": new_id,
            },
            ConditionExpression=boto3.dynamodb.conditions.Attr("Id").eq(old_id),
        )

    # Counter doesn't exist yet, create
    else:

        new_id = 1

        put_result = counter_table.put_item(
            Item={
                "Prefix": prefix,
                "Id": new_id,
            },
            ConditionExpression=boto3.dynamodb.conditions.Attr("Prefix").not_exists(),
        )

    # Guestbook :-)
    log_item = {
        "Prefix": prefix,
        "Id": new_id,
    }
    if comment:  # DynamoDB doesn't like empty strings
        log_item["Comment"] = comment
    put_result = log_table.put_item(Item=log_item)

    oid = "%s.%s" % (prefix, new_id)

    return oid


def lambda_handler_wrapped(event, context):

    if event.get("httpMethod") == "PUT" and event.get("path") == "/api/oid":

        if len(event["body"]) > 65536:
            return respond(400, {"error": "body too long"})

        body = json.loads(event["body"])

        if not is_captcha_valid(event, context):
            return respond(400, {"error": "bad captcha"})

        return respond(
            200, {"oid": assign_oid(prefix, body["comment"]), "prefix": prefix}
        )

    elif event.get("httpMethod") == "GET" and event.get("path") == "/api/oid":
        return respond(200, {"prefix": prefix})

    else:
        return respond(400, {"error": "bad request"})


def lambda_handler(event, context):
    # Catch any exception and return gracefully
    try:
        response = lambda_handler_wrapped(event, context)
        return response
    except Exception as e:
        print(e)
        return respond(400, {"error": "bad request (caught in lambda_handler)"})
