# A Little History

The utilities reimplemented in this repository were not anonymous system software. A
published history of computing in the Argentine state names their author, the organisation
that built them, and the reason they were built at all.

## The source

> Pablo A. Fontdevila, Arturo Laguado Duca and Horacio Cao,
> ***40 años de informática en el Estado argentino***.
> Buenos Aires: EDUNTREF — Universidad Nacional de Tres de Febrero, first edition,
> November 2007. 170 pp.
> Research carried out within the Centro de Investigación en Administración Pública (CIAP),
> Facultad de Ciencias Económicas, Universidad de Buenos Aires.

Publicly funded research, distributed free of charge by its authors: co-author **Horacio Cao**
publishes this same PDF for download on his own website —
[horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf](https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf)
([Wayback Machine snapshot, 2021-05-08](https://web.archive.org/web/20210508192023/https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf),
the copy retrieved here).

The passage below is on **page 37** of
[`Cuarenta_anos_de_informatica_en_el_Estado.pdf`](Cuarenta_anos_de_informatica_en_el_Estado.pdf),
in the section *La edad de oro del CUPED*. It is the **only** mention of the utilities, and
of their author, in the whole book.

## The passage

The paragraph that sets the scene — an in-house R&D group, and an explicit policy of
building your own tools to depend less on the vendor:

> La creación de un área de investigación y de desarrollo –llamados con sorna y algo de
> envidia por sus compañeros “los becados”- y otra de capacitación, completaron el proyecto.
> A partir de los ’70, se incursionó en el software de base de IBM y en el diseño de
> utilitarios, tratando de reducir la dependencia con la firma norteamericana.

> *The creation of a research and development area — mockingly and somewhat enviously called
> “the scholarship holders” by their colleagues — and another for training completed the
> project. From the ’70s onwards they moved into IBM's base software and into designing
> utilities, trying to reduce dependence on the American firm.*

Then the utilities themselves:

> El desarrollo más reconocido fue el de dos utilitarios modulares desarrollados por Jorge
> Vattuone en el área de programación del CUPED. Estas dos herramientas – OS GENER y OS LIST
> - estaban diseñadas para formar parte del sistema operativo y así realizar tareas que, de
> otra manera, hubieran necesitado programas específicos. Con ellas, entre otras cosas, se
> podía aparear archivos o listas para reemplazar ó copiar datos de uno en otro, modificar o
> convertir datos de una tabla o archivo a otro, buscar archivos o tablas para seleccionar ó
> eliminar registros, etc. No hubo implementador, programador o analista que no haya echado
> mano a ellos ante cualquier contingencia.

> *The most recognised development was two modular utilities written by Jorge Vattuone in the
> CUPED programming area. These two tools — OS GENER and OS LIST — were designed to form part
> of the operating system and so perform tasks that would otherwise have needed
> purpose-written programs. With them, among other things, one could match files or lists to
> replace or copy data from one into another, modify or convert data from one table or file
> to another, search files or tables to select or delete records, etc. There was no
> implementer, programmer or analyst who did not reach for them in any contingency.*

And, closing the same page:

> El OS GENER y el OS LISTA fueron agregados a la rutina de trabajo del CUPED con tanto éxito
> que IBM los incorporó a su sistema operativo, usándolos hasta principios del siglo XXI.

> *OS GENER and OS LISTA were added to the CUPED's working routine with such success that IBM
> incorporated them into its operating system, using them until the early 21st century.*

Interleaved between those paragraphs, the caption to a photograph of a January 1969
employment contract fixes the organisation's earlier name:

> Contrato de enero de 1969 como “Analista de Segunda” del Sr. Lazlo de Suto Nagy, hoy
> funcionario de la Gerencia de Sistemas y Telecomunicaciones. Nótese que el contrato refiere
> al CUSDI, primer nombre con que se conoció al CUPED.

## What this establishes

**The author.** *Jorge Vattuone*, working in the programming area of the CUPED.

**The organisation.** The **CUPED** — *Centro Único de Procesamiento Electrónico de Datos* —
created on 18 October 1967 under the Secretaría de Estado de Seguridad Social, and for
decades the centralised data-processing centre of the Argentine state. It was originally the
**CUSDI**; the book expands that acronym two different ways in two different places
(*Centro Único de Sistematización de la Información* and *Centro Único de Procesamiento de
Datos e Información*), so treat either with caution.

**The design brief, which the code bears out.** Every capability the paragraph lists has a
direct counterpart in the control-card language this project implements:

| The book says | Implemented as |
|---|---|
| match files or lists | `CLAVE` (SYSUT3 match), `PESQIN` / `PESQOUT` (probe file) |
| replace or copy data from one into another | `COPY`, `FIELD` |
| convert data from one table or file to another | `CONV` and its lookup tables |
| search to select or delete records | `RCIN` / `RCOUT` |

That the list matches the surviving manual so exactly is decent evidence that the 1/84
publication really does document the tools the book is describing.

## Two things not established

**The `SCD` on the manual's cover.** Every sheet of `docs/manual/OSLSGEN.txt` is headed
`SCD - CENTRO DE COMPUTOS - DEPARTAMENTO DE INGENIERIA`. The book uses the same three letters
once, for an advisory body:

> Presidencia de la Nación, se creó una asesoría en Sistemas de Computación de Datos (SCD) que
> dio origen a las primeras normas oficiales sobre adquisición y utilización de computadoras
> en la Administración Pública.

That gives a plausible expansion — *Sistemas de Computación de Datos* — but **not** a
confirmed identification. The book's SCD is a policy and standards advisory unit under the
Presidencia; the manual's SCD has its own computing centre and engineering department, which
is a different kind of organisation. The two may be related, successive, or unconnected. The
book never links either to the 1/84 publication.

**The IBM claim.** That IBM absorbed the utilities into its own operating system and shipped
them into the 21st century is the book's assertion, repeated here as such. No corroboration
was found, and it should be attributed to the source rather than restated as fact.

## Distribution status

The CUPED released the binaries and the manual as public-domain software within the public
administration. That is why the 1/84 publication can be reproduced in full under
`docs/manual/`.

## Notes on the quotations

Spanish text is reproduced exactly as it appears in the PDF, including the source's own
spacing around dashes and its accented `ó` where the conjunction *o* is meant
(*“reemplazar ó copiar”*, *“seleccionar ó eliminar”*). The book writes the names
inconsistently — *OS GENER* and *OS LIST* in one paragraph, *OS GENER* and *OS LISTA* in the
next; the manual itself uses the unspaced **OSGENER** and **OSLISTA** throughout, and this
project follows the manual.
