# Informe Comparativo: Terraform vs. Pulumi (Laboratorio 02)


**Curso:** Fundamentos de DevOps y SRE (2026-01) – Universidad Nacional de Colombia, Sede Bogotá
**Grupo:** grupo03


**Integrantes:**
- Juan David Carranza Sanchez – R1 (Terraform)
- Pablo Esteban Olaya Arias – R2 (Pulumi)
- Diana Fernanda Reyes Marciales – R3 (Platform & CI Lead)


---


## 7.1 Matriz de Comparación Empírica


| Criterio | Terraform (HCL) | Pulumi (Python) | Análisis del grupo con evidencia observada |
|---|---|---|---|
| **1. Curva de aprendizaje y sintaxis** | DSL declarativo especializado. Hay que aprender bloques (`resource`, `variable`, `output`), referencias entre recursos (`docker_network.app_network.name`) e interpolación `"${...}"`. | Lenguaje general orientado a objetos. Quien ya sabe Python reutiliza condicionales, f-strings y funciones; lo nuevo es el modelo de recursos y los `Args` del provider. | R1 tardó **5 min** en tener el contenedor funcionando y R2 **7 min**. Con Terraform el esfuerzo estuvo en la sintaxis de bloques anidados (`labels {}`, `ports {}`); con Pulumi, en los tipos `docker.ContainerPortArgs` / `ContainerLabelArgs` y en el entorno virtual. Indicar cuál experiencia previa influyó. |
| **2. Líneas de código efectivas (LOC)** | **97** líneas en `terraform/*.tf` (main 48, variables 24, outputs 14, versions 9, providers 2), sin comentarios ni líneas en blanco. `terraform.tfvars.example` (4 líneas) queda fuera del total. | **55** líneas en `__main__.py` (sin comentarios, líneas en blanco ni docstring); **69** si se suman `Pulumi.yaml` (6), `Pulumi.dev.yaml` (6) y `requirements.txt` (2). | Pulumi fue más compacto: 55 frente a 97 líneas (≈ 43 % menos); si se incluyen los archivos de configuración, 69 frente a 97 (≈ 29 % menos). Terraform exige un bloque por cada `label` y separa la lógica en cinco archivos, lo que aumenta el boilerplate pero deja cada responsabilidad más fácil de ubicar. Conteo hecho con un script que excluye líneas vacías, comentarios (`#`, `//`) y docstrings de Python. |
| **3. Manejo del estado (State)** | Un único archivo JSON `terraform.tfstate` en la carpeta del proyecto, legible directamente; también con `terraform state list` y `terraform show`. | Estado del stack en el backend local (`~/.pulumi`), consultable con `pulumi stack`, `pulumi stack --show-urns` y `pulumi stack export`. | Terraform fue más fácil de inspeccionar "a simple vista" (abrir el archivo). Pulumi requiere comandos de CLI, pero ofrece una vista ordenada de recursos y outputs. Ambos contienen información sensible potencial, por eso el `.gitignore` excluye `*.tfstate` y `.pulumi/`. En la sección de evidencias, se encuentran los pantallazos referentes al trabajo. |
| **4. Validación de variables y tipos** | Bloque `validation { condition = contains([...], var.environment) }` con `error_message` declarativo. Se evalúa en `plan`/`validate`; los tipos (`string`, `number`) se verifican antes de tocar la infraestructura. | Lógica imperativa: `if environment not in valid_envs: raise ValueError(...)`. Se evalúa al ejecutar el programa (`pulumi preview`/`up`). Los tipos dependen de Python (hints opcionales). | Terraform detecta el error en `terraform validate`/`plan` con un mensaje estructurado y con la línea exacta; Pulumi muestra un traceback de Python, más largo pero igualmente claro. Pulumi permite validaciones más ricas (regex, rangos, llamadas a funciones). |
| **5. Detección y corrección de drift** | `terraform plan` refresca el estado real contra la API de Docker por defecto, detecta que el contenedor no existe y propone `1 to add`. `terraform apply` lo recrea. | `pulumi preview --refresh` consulta Docker y muestra la diferencia; el contenedor aparece como recurso a crear. Ojo: `preview` no persiste el refresh; para actualizar el estado se usa `pulumi refresh` o `pulumi up --refresh`. | Ambas herramientas detectaron el borrado manual (`docker rm -f`). Diferencia clave: Terraform refresca implícitamente en cada `plan`, Pulumi lo hace solo con `--refresh`/`pulumi refresh`.|
| **6. Multiplicidad y ciclos** | Meta-argumentos `count` y `for_each` en el propio recurso (ver ejemplo abajo). | Bucle `for` estándar de Python o comprensiones de listas (ver ejemplo abajo). | Para 10 réplicas, Python resulta más familiar y flexible (nombres, puertos y lógica condicional con código normal). `for_each` en Terraform es más declarativo y mantiene direcciones estables por clave (`docker_container.web["a"]`), pero es menos intuitivo al principio. |
| **7. Ecosistema de linters / Shift-Left** | `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`. Requiere descargar el provider en CI. | `ruff check`, `flake8` (solo errores graves). Herramientas rápidas y estándar del ecosistema Python. | Tiempos tomados del pipeline de GitHub Actions: job Terraform **6 s**, job Pulumi **10 s** (ver pestaña *Actions*). Esperado: Ruff/Flake8 son casi instantáneos; en Terraform pesa `terraform init` por la descarga del provider. Importante: ninguno de los dos pipelines ejecuta `plan` ni `preview`, por lo que no detecta errores de despliegue reales. |


---


## 7.2 Evidencias del Experimento de Drift


### Terraform

Salida de `terraform plan` (ejecutado por R1):
![Evidencia de Terraform.](Terraform.JPEG)

### Pulumi

![Evidencia de Pulumi.](pulumi.JPEG)


---


## 7.3 Conclusión Arquitectónica


Si tuviéramos que desplegar una arquitectura de microservicios en una empresa donde todos los desarrolladores son de Python pero no tienen experiencia en DevOps, elegiríamos **Pulumi con Python**. La razón principal es la barrera de entrada: el equipo ya domina el lenguaje, sus herramientas (IDE, linters, pruebas unitarias, depuración) y construcciones como bucles, funciones y clases, que permiten definir muchos microservicios parametrizados sin repetir código, como mostró nuestro experimento de LOC (55 frente a 97 líneas). Esto reduce el tiempo de adopción y permite que los desarrolladores se involucren en la infraestructura de sus propios servicios, en lugar de depender de un único especialista en HCL. Reconocemos que Terraform tiene un ecosistema más amplio, más ejemplos y una comunidad mayor, y que su carácter declarativo limita la lógica en la infraestructura, lo que en equipos sin experiencia puede ser una ventaja de seguridad.


Esa flexibilidad exige precauciones, porque con un lenguaje general es fácil escribir infraestructura difícil de razonar. Recomendaríamos: (1) estado remoto con bloqueo y cifrado en lugar del backend local, y secretos gestionados con el mecanismo de la herramienta, nunca en el repositorio; (2) pipeline de CI que ejecute `pulumi preview` en cada Pull Request, con revisión obligatoria, ya que nuestro pipeline solo valida formato y sintaxis; (3) políticas como código (por ejemplo, CrossGuard) para impedir configuraciones inseguras; (4) versiones fijadas de dependencias y componentes reutilizables y revisados para los patrones comunes; (5) ambientes separados (dev/staging/prod) con stacks distintos y detección periódica de drift (`pulumi refresh`); y (6) capacitación básica en conceptos de DevOps (estado, idempotencia, ciclo de vida de recursos), porque la herramienta no sustituye ese conocimiento.

---