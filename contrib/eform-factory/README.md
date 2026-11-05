# eForm Factory

A small toolchain for turning paper requisitions / referral forms into
production-quality **OSCAR eForms** with patient auto-prefill, a
signing-physician dropdown (with per-physician signature images), a
handwriting signature pad, and one-command publishing into `oscar.eform`.

Built and battle-tested on an open-osp production clinic (BC, Canada);
extracted here so other deployments don't have to rediscover the sharp edges.

```
scanned form image
      │  (rebuild by hand or with your favourite HTML tooling)
      ▼
clean visual template  ──►  eformify.py  ──►  <name>_eform.html  ──►  insert_eform.py  ──►  oscar.eform row
      (conventions below)      (adds OSCAR machinery)                    (idempotent publish, no restart)
```

## Quick start

```bash
cd contrib/eform-factory
cp eformify_config.example.json eformify_config.json   # edit: your physicians
./eformify.py examples/demo_requisition.html --subject "Demo Requisition"
./insert_eform.py examples/demo_requisition_eform.html \
    --name "Demo_Requisition" --subject "Demo Requisition"
```

Open OSCAR → patient → eForms → *Demo_Requisition*. Patient data is
prefilled; pick the physician in the toolbar; Submit stores it to the chart.
Publishing is instant (eForm HTML lives only in the `eform` DB table) —
**no container restart, ever**.

## What eformify injects

* Toolbar: subject box, **Submit to Chart** (`name="SubmitButton"` — required
  by OSCAR), **Print**, **Clear signature**.
* **Physician dropdown** — defaults to the logged-in user (matched by name
  against `oscarDB=current_user`); an MOA filling the form can switch it.
  Selecting a physician live-updates the printed name, MSP number field
  (`msp_billing`), phone (`physician_tel`), a hidden `signing_provider_no`,
  and the signature: physicians with a stored signature image get the image,
  everyone else gets a **jSignature handwriting pad** (persisted via the
  standard `StoreSignature1` hidden field).
* **Copies-to dropdown** (only when the template contains
  `<input name="copies_to">`).
* Hidden `oscarDB` carriers + prefill JS: patient name, DOB split into
  DD / MON / YYYY (and numeric MM) boxes, sex checkboxes, city/province/postal
  combined into `address2`.

## Template conventions

Write a plain HTML page — no OSCAR logic — following these rules:

| Thing | Convention |
|---|---|
| Page container | `<div id="page">`, **1020 px** wide (Letter proportions) |
| Fill-in lines | `<input class="line">` (bottom border only) |
| Print | `@media print { @page{size:letter;margin:0.15in} #page{zoom:0.78} }` — must print to **exactly one Letter page** |
| PHN | `<input name="phn" data-oscar-key="patient_phn">` (exact string; gets `oscarDB=hin`) |
| Street address | `<input name="address1" data-oscar-key="patient_address_street">` |
| Patient phone | `<input name="tel" data-oscar-key="patient_phone">` |
| Patient name | `name="patient_name"` (filled "Last, First"); also `patient_surname` / `patient_firstname` if you need them split |
| DOB | inputs named `dob_dd`, `dob_mon` (JAN…DEC) and/or `dob_mm` (01…12), `dob_yyyy` |
| Sex | optional checkboxes `sex_m` / `sex_f` |
| Signature block | ```<div class="sigcell"><input class="line" name="physician_signature"><span class="cap">Physician&rsquo;s signature</span></div>``` — eformify swaps this whole div for the image+pad widget. The `&rsquo;` entity and the class names are the anchor; whitespace/newlines inside are fine. |
| Physician name / MSP / phone | `physician_name`, `msp_billing`, `physician_tel` — auto-filled from the dropdown |
| Copies to | `<input name="copies_to">` enables the dropdown |
| Other prefill | you may put `oscarDB=<tag>` directly on any input of your own |

After running eformify, **check the summary line**: it prints
`signature widget: yes/NO`. `NO` means your sigcell block didn't match.

## oscarDB tag cheat sheet (verified on OSCAR 19)

`hin` (PHN) · `patient_nameF` / `patient_nameL` · `dobc` · `sex` ·
`addressline` · `city` · `province` · `postal` · `phone` · `cell` ·
`clinic_phone` · `today` · `current_user`

Sharp edges we hit so you don't have to:

* **`oscarDB=doctor` is the patient's MRP, not the logged-in user.** Use
  `oscarDB=current_user` (format `"Last, First_123"`; strip the `_suffix`).
* **DOB formats differ by tag and build**: `dobc` emits `dd/mm/yyyy`
  (slashes) on stock builds, `dob` adds a `(d/m/y)` suffix, `dobc2` is
  `yyyy/mm/dd`, `dob_MONTH-dd-yyyy` is `Mon-dd-yyyy`. The injected prefill JS
  parses dashes, slashes (both orders) and `dd-Mon-yyyy`, so any of these
  work. There are also `dob_year` / `dob_month` / `dob_date` single-value
  tags if you prefer no parsing at all.
* Hidden `name="provider_no"` `$provider_no` substitution does **not** work
  reliably; don't depend on it (that's why the dropdown writes
  `signing_provider_no`).
* The MSP practitioner number is `provider.ohip_no`. `provider.billing_no`
  is typically a clinic group number — wrong thing to print on a requisition.

## Signature images

Store per-physician signature PNGs (transparent background recommended) in
OSCAR's eForm image directory
(`/var/lib/OscarDocument/oscar/eform/images/` in the standard open-osp
layout) and reference them by filename in `eformify_config.json`. They're
served by `../eform/displayImage.do?imagefile=<name>` — no restart needed
after dropping a file in.

## Publishing / updating / rolling back

* `insert_eform.py` is idempotent on `form_name`: first run INSERTs (and
  prints the new `fid` + a rollback `DELETE`), later runs UPDATE the same row.
* To edit a live form: change the template → re-run `eformify.py` →
  re-run `insert_eform.py` → hard-refresh the browser. Nothing restarts.
* eForm HTML lives **only** in the DB (`oscar.eform.form_html`) — don't look
  for it on the filesystem.

## Security notes

* Templates must contain **no PHI** — patient data arrives only via the
  `oscarDB` mechanism at render time.
* `insert_eform.py` runs `mysql` **inside** the compose `db` container using
  its own `MYSQL_ROOT_PASSWORD` env var, so no credentials land on the host
  or in your shell history.
* Keep your real `eformify_config.json` (physician names / MSP numbers) out
  of version control if your repo is public — only the `.example.json`
  belongs in git.
