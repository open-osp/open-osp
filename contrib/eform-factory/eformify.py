#!/usr/bin/env python3
"""eformify — turn a clean HTML form template into a production OSCAR eForm.

Given a plain "visual" HTML template (typically rebuilt from a scanned paper
requisition), this tool injects the standard OSCAR eForm machinery:

  * a toolbar: subject field / "Submit to Chart" / Print / clear-signature
  * a signing-physician dropdown (defaults to the logged-in user; an MOA can
    switch it) that live-updates the printed name, MSP practitioner number,
    phone and signature image
  * a "Copies to" dropdown (only if the template has an input named copies_to)
  * hidden oscarDB carriers for patient prefill + JS that splits the DOB into
    DD / MON / YYYY boxes and ticks sex checkboxes
  * a jSignature handwriting pad as fallback for physicians without a stored
    signature image

Usage:
    ./eformify.py template.html --subject "PHC Vascular Requisition" \
        [--config eformify_config.json] [--out template_eform.html]

Then publish the output with insert_eform.py (see README.md).

Template conventions (see README.md for the full list):
  * page container:  <div id="page"> ... </div>, 1020px wide
  * patient hooks (exact strings, get oscarDB attributes injected):
        name="phn"      data-oscar-key="patient_phn"
        name="address1" data-oscar-key="patient_address_street"
        name="tel"      data-oscar-key="patient_phone"
  * DOB boxes named dob_dd / dob_mon / dob_yyyy (and/or dob_mm, numeric)
  * sex checkboxes named sex_m / sex_f (optional)
  * signature placeholder (replaced by the signature widget):
        <div class="sigcell" ...> ... Physician&rsquo;s signature</span></div>
  * optional <input name="copies_to"> enables the Copies-to dropdown
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent


def load_doctors(config: dict) -> list[dict]:
    """Build the dropdown list from config. Each entry needs last_name,
    first_name, provider_no; msp and sig (signature image filename inside
    OSCAR's eform images directory) are optional."""
    docs = []
    for d in config["doctors"]:
        last = d["last_name"].strip()
        first = d["first_name"].strip()
        docs.append({
            "no": str(d["provider_no"]),
            "label": f"{last}, {first}",
            "msp": (d.get("msp") or "").strip(),
            "sig": (d.get("sig") or "").strip(),
            "match": f"{last}|{first}".lower().replace(" ", ""),
        })
    return docs


EXTRA_CSS = """
/* -- eForm toolbar & signature pad (eformify) -- */
#toolbar {
  max-width: 1020px; margin: 0 auto 8px; padding: 8px 12px;
  background: #10314f; color: #fff; display: flex; align-items: center; gap: 8px;
  border-radius: 4px; font-size: 13px; flex-wrap: wrap;
}
#toolbar label { font-size: 12px; white-space: nowrap; }
#toolbar select { padding: 4px 6px; border: 0; border-radius: 3px; font-size: 13px; max-width: 190px; }
#toolbar input[type="text"] { flex: 1; min-width: 160px; padding: 4px 8px; border: 0; border-radius: 3px; font-size: 13px; }
#toolbar button, #toolbar input[type="submit"] {
  padding: 5px 12px; border: 0; border-radius: 3px; cursor: pointer; font-weight: bold; font-size: 13px;
}
#btn-submit { background: #2ecc71; color: #fff; }
#btn-print { background: #3498db; color: #fff; }
#btn-clearsig { background: #95a5a6; color: #fff; }
#sigpad { border: 1px dashed #999; height: 46px; width: 200px; background: #fff; }
.sig-printed { font-size: 11px; font-style: italic; }
@media print { #toolbar { display: none; } #sigpad { border: 0; } body { background: #fff; } }
"""

TOOLBAR = """
<form method="post" action="" name="FormName" id="FormName">
<div id="toolbar">
  <input name="subject" type="text" value="__SUBJECT__">
  <label>Physician:
    <select id="dr_select" onchange="applyDoctor()">__DR_OPTIONS__</select>
  </label>
  __FORWARD_WIDGET__
  <input id="btn-submit" value="Submit to Chart" name="SubmitButton" type="submit"
         onclick="saveSig(); if(typeof releaseDirtyFlag==='function')releaseDirtyFlag();">
  <button id="btn-print" type="button" onclick="saveSig();window.print()">Print</button>
  <button id="btn-clearsig" type="button" onclick="clearSig()">Clear signature</button>
</div>
<!-- oscarDB prefill carriers (values injected server-side when the eForm renders) -->
<input type="hidden" name="o_nameF" oscarDB=patient_nameF>
<input type="hidden" name="o_nameL" oscarDB=patient_nameL>
<input type="hidden" name="o_dob" oscarDB=dobc>
<input type="hidden" name="o_sex" oscarDB=sex>
<input type="hidden" name="o_city" oscarDB=city>
<input type="hidden" name="o_province" oscarDB=province>
<input type="hidden" name="o_postal" oscarDB=postal>
<input type="hidden" name="o_curuser" oscarDB=current_user>
<input type="hidden" name="signing_provider_no" id="signing_provider_no" value="">
<input type="hidden" name="StoreSignature1" id="StoreSignature1" value="">
<input type="hidden" name="demographic_no" value="">
"""

FORWARD_WIDGET = """
  <label>Copies to:
    <select id="fw_select" onchange="applyForward()">__FW_OPTIONS__</select>
  </label>
"""

JS = """
<script type="text/javascript" src="${oscar_image_path}jSignature.min.js"></script>
<script>
function V(n){var e=document.getElementsByName(n)[0];return e?(e.value||"").trim():"";}
function S(n,v){var e=document.getElementsByName(n)[0];if(e&&!e.value&&v)e.value=v;}
var MON=["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
var CLINIC_PHONE="__CLINIC_PHONE__";

function normName(s){
  s=(s||"").split("_")[0]+(s.indexOf(",")>-1?","+s.split(",")[1].split("_")[0]:"");
  var parts=(s||"").toLowerCase().split(",");
  var last=(parts[0]||"").replace(/[^a-z]/g,"");
  var first=((parts[1]||"").trim().split(/[\\s_-]/)[0]||"").replace(/[^a-z]/g,"");
  return last+"|"+first;
}

function applyDoctor(){
  var sel=document.getElementById("dr_select");
  var opt=sel.options[sel.selectedIndex];
  if(!opt)return;
  var el=document.getElementById("dr_printed");
  if(el)el.textContent=opt.getAttribute("data-label")||opt.text;
  var bill=document.getElementsByName("msp_billing")[0];
  if(bill)bill.value=opt.getAttribute("data-msp")||"";
  var tel=document.getElementsByName("physician_tel")[0];
  if(tel&&!tel.value)tel.value=CLINIC_PHONE;
  var pname=document.getElementsByName("physician_name")[0];
  if(pname)pname.value=opt.getAttribute("data-label")||opt.text;
  var pn=document.getElementById("signing_provider_no");
  if(pn)pn.value=opt.value||"";
  // Signature: show the stored image if this physician has one, else the pad
  var sig=opt.getAttribute("data-sig")||"";
  var img=document.getElementById("dr_sigimg");
  var pad=document.getElementById("sigpad");
  if(img&&pad){
    if(sig){
      img.src="../eform/displayImage.do?imagefile="+encodeURIComponent(sig);
      img.style.display="";pad.style.display="none";
    }else{
      img.style.display="none";img.removeAttribute("src");pad.style.display="";
    }
  }
}

function defaultDoctor(){
  var cu=V("o_curuser");
  var sel=document.getElementById("dr_select");
  if(!sel)return;
  if(cu&&cu.indexOf("$")===-1){
    var key=normName(cu);
    for(var i=0;i<sel.options.length;i++){
      if(sel.options[i].getAttribute("data-match")===key){sel.selectedIndex=i;applyDoctor();return;}
    }
    // Current user is not in the configured list (e.g. an MOA):
    // add a temporary entry, preselect it, allow manual switching.
    var o=document.createElement("option");
    var nice=cu.replace(/_[A-Za-z0-9]+/g,"");
    o.text=nice+" (current user)";o.value="";o.setAttribute("data-label",nice);
    sel.insertBefore(o,sel.firstChild);sel.selectedIndex=0;applyDoctor();
  }
}

function applyForward(){
  var sel=document.getElementById("fw_select");
  if(!sel)return;
  var v=sel.value;
  var tgt=document.getElementsByName("copies_to")[0];
  if(tgt&&v)tgt.value=v;
}

function prefill(){
  var f=V("o_nameF"),l=V("o_nameL");
  if(f||l)S("patient_name",(l&&f)?(l+", "+f):(l||f));
  S("patient_surname",l);S("patient_firstname",f);
  var line2=[V("o_city"),V("o_province"),V("o_postal")].filter(function(x){return x;}).join(", ");
  if(line2)S("address2",line2);
  // NOTE: oscarDB=dobc emits dd/mm/yyyy (slashes) on stock OSCAR builds,
  // but other deployments emit yyyy-mm-dd or dd-Mon-yyyy. Parse all of them.
  var d=V("o_dob"),m;
  if((m=d.match(/(\\d{4})-(\\d{1,2})-(\\d{1,2})/))){
    S("dob_yyyy",m[1]);S("dob_mon",MON[+m[2]-1]||"");S("dob_dd",("0"+m[3]).slice(-2));
    S("dob_mm",("0"+m[2]).slice(-2));
  }else if((m=d.match(/(\\d{1,2})[-\\s]([A-Za-z]{3})[a-z]*[-,\\s]+(\\d{4})/))){
    S("dob_dd",("0"+m[1]).slice(-2));S("dob_mon",m[2].toUpperCase());S("dob_yyyy",m[3]);
    S("dob_mm",("0"+(MON.indexOf(m[2].toUpperCase())+1)).slice(-2));
  }else if((m=d.match(/^\\s*(\\d{1,2})\\/(\\d{1,2})\\/(\\d{4})/))){
    S("dob_dd",("0"+m[1]).slice(-2));S("dob_mon",MON[+m[2]-1]||"");S("dob_yyyy",m[3]);S("dob_mm",("0"+m[2]).slice(-2));
  }else if((m=d.match(/^\\s*(\\d{4})\\/(\\d{1,2})\\/(\\d{1,2})/))){
    S("dob_yyyy",m[1]);S("dob_mon",MON[+m[2]-1]||"");S("dob_dd",("0"+m[3]).slice(-2));S("dob_mm",("0"+m[2]).slice(-2));
  }
  var sx=V("o_sex").toUpperCase();
  var em=document.getElementsByName("sex_m")[0],ef=document.getElementsByName("sex_f")[0];
  if(em&&sx.indexOf("M")===0)em.checked=true;
  if(ef&&sx.indexOf("F")===0)ef.checked=true;
}

function saveSig(){
  try{var dp=jQuery("#sigpad").jSignature("getData","base30");
      document.getElementById("StoreSignature1").value=dp.join(",");}catch(e){}
}
function clearSig(){try{jQuery("#sigpad").jSignature("reset");}catch(e){}}
function loadSig(){
  try{var v=document.getElementById("StoreSignature1").value;
      if(v)jQuery("#sigpad").jSignature("setData","data:"+v);}catch(e){}
}

document.addEventListener("DOMContentLoaded",function(){
  prefill();defaultDoctor();
  try{jQuery("#sigpad").jSignature();loadSig();}catch(e){}
});
</script>
"""

SIG_CELL = ('<div class="sigcell" style="flex:0 0 210px">'
            '<img id="dr_sigimg" src="" alt="" style="display:none;height:42px;max-width:200px;object-fit:contain">'
            '<div id="sigpad"></div>'
            '<span class="sig-printed" id="dr_printed"></span>'
            '<span class="cap">Physician&rsquo;s signature</span></div>')


def eformify(template: Path, subject: str, config: dict, out: Path):
    src = template.read_text()
    docs = load_doctors(config)

    dr_opts = "".join(
        f'<option value="{d["no"]}" data-label="{d["label"]}" data-msp="{d["msp"]}" '
        f'data-sig="{d["sig"]}" data-match="{d["match"]}">{d["label"]}</option>'
        for d in docs)

    has_copies = 'name="copies_to"' in src
    fw = ""
    if has_copies:
        fw_opts = '<option value="">&mdash; type manually &mdash;</option>' + "".join(
            f'<option value="{o}">{o}</option>' for o in config.get("forward_options", [])) + "".join(
            f'<option value="Dr. {d["label"].split(",")[1].strip()} {d["label"].split(",")[0]}">'
            f'{d["label"]}</option>' for d in docs)
        fw = FORWARD_WIDGET.replace("__FW_OPTIONS__", fw_opts)

    toolbar = (TOOLBAR.replace("__SUBJECT__", subject)
               .replace("__DR_OPTIONS__", dr_opts)
               .replace("__FORWARD_WIDGET__", fw))
    js = JS.replace("__CLINIC_PHONE__", config.get("clinic_phone", ""))

    # Ordered replacements; each works on the current text (never reuse offsets).
    src = src.replace("</style>", EXTRA_CSS + "</style>", 1)
    src = src.replace("<body>", "<body>" + toolbar, 1)
    src = src.replace('name="phn" data-oscar-key="patient_phn"',
                      'name="phn" oscarDB=hin data-oscar-key="patient_phn"', 1)
    src = src.replace('name="address1" data-oscar-key="patient_address_street"',
                      'name="address1" oscarDB=addressline data-oscar-key="patient_address_street"', 1)
    src = src.replace('name="tel" data-oscar-key="patient_phone"',
                      'name="tel" oscarDB=phone data-oscar-key="patient_phone"', 1)

    # Whitespace-tolerant: `</span>` and `</div>` may be separated by newlines.
    old_sig = re.search(
        r'<div class="sigcell"[^>]*>.*?Physician&rsquo;s signature</span>\s*</div>', src, re.S)
    if old_sig:
        src = src.replace(old_sig.group(0), SIG_CELL, 1)

    src = src.replace("</body>", "</form>\n" + js + "</body>", 1)

    assert src.index("<form method") < src.index('<div id="page">')
    assert 'id="toolbar"' in src and "</form>" in src
    n_sigpad = src.count('id="sigpad"')
    out.write_text(src)
    print(f"OK -> {out} ({len(src)} bytes) | {len(docs)} doctors | "
          f"copies-to widget: {'yes' if has_copies else 'no'} | "
          f"signature widget: {'yes' if n_sigpad else 'NO (check your sigcell block!)'}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("template")
    ap.add_argument("--subject", required=True)
    ap.add_argument("--config", default=str(ROOT / "eformify_config.json"))
    ap.add_argument("--out")
    a = ap.parse_args()
    t = Path(a.template)
    cfg = json.loads(Path(a.config).read_text())
    out = Path(a.out) if a.out else t.with_name(t.stem + "_eform.html")
    eformify(t, a.subject, cfg, out)
