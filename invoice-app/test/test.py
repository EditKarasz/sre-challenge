import requests
import os
from string import printable
import sys

external_ip = sys.argv[1]

## These information can come from kubectl queries
payment_url = (
    "http://payment-provider.payment-provider.svc.cluster.local:8082/payments/pay"
)


def GetInvoicesUrl():
    if external_ip:
        invoice_url = f"http://{external_ip.strip()}:8081/invoices"
        print(invoice_url)
        return invoice_url
    else:
        print(f"The appication is not running. {external_ip}")
        raise SystemExit(1)


def PayInvoice(invoice):
    try:
        response = requests.post(
            payment_url,
            json={
                "InvoiceId": invoice["InvoiceId"],
                "Value": invoice["Value"],
                "Currency": invoice["Currency"],
            },
        )

        return print(
            f"Status Code: {response.status_code}, Response: {response.json()}"
        )
    except requests.exceptions.HTTPError as error:
        print(f"HTTP error occurred: {error}")
    except Exception as error:
        print(f"Other error occurred: {error}")


## Get invoices url
url = GetInvoicesUrl()

## Collect invoices
try:
    response = requests.get(url)
except requests.exceptions.HTTPError as error:
    print(f"HTTP error occurred: {error}")
    raise SystemExit(1)
except Exception as error:
    print(f"Other error occurred: {error}")
    SystemExit(1)

invoices = response.json()

## Pay unpaid invoices
for invoice in invoices:
    if not invoice["IsPaid"]:
        PayInvoice(invoice)
