# Global -> Repo Mapping (承接映射)

## Mapping
- `R1` -> `A.2 + C.1 + C.7` (归宿先行与回灌闭环)
- `R2/R3` -> `A.2 + C.2 + C.3` (小步闭环与根因优先)
- `R4/R6` -> `C.2 + C.3 + C.4` (硬门禁、N/A 回退与阻断)
- `R7` -> `A.1 + C.6` (边界与兼容保护)
- `R8/E3` -> `A.2 + C.5` (证据与回滚可追溯)
- `E4/E5/E6` -> `C.4 + C.6 + C.8` (指标、供应链与结构变更校验)

## Field Mapping
- Global output -> repo evidence fields:
  - `N/A 分类/判定标准` -> `A.3`
  - `门禁语义` -> `C.2/C.4`
  - `证据要求` -> `C.5`

## Layer Boundary
- Global owns: rule semantics and judgment standards.
- Repo owns: commands, evidence path, rollback entry, block decisions.
- Constraint: repo layer must not override global semantics.
