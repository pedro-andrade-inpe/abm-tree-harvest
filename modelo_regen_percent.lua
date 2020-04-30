import("gis")

proj  = Project {
    file = "project_regen.qgs",
    grid = "dados/CELL_GRID_ENTRADA_MODELO.shp",
    clean = true,
}

--[[
class 1 = [0, 10)
class 2 = [10,20)
...
class 6 = [50, 60)
...
class 9 = [80, inf)
]]--
NAME = "braz_2017"
IDAs = {}
IDAs["braz_2017"] = {
    0.291,        -- class1
    0.317,        -- class2
    0.442,        -- class3
    0.473,        -- class4
    0.623,        -- class5
    0.587,        -- class6
    0.587,        -- class7
    0.717,        -- class8
    0.836,        -- class9
}
IDAs["borges"] = {
    .287,
    .325,
    .437,
    .452,
    .470,
    .478,
    .531,
    .417,
    .0,
}
IDAs["canneti"] = {
    .283,
    .377,
    .451,
    .475,
    .485,
    .493,
    .569,
    .580,
    .546,
}
IDAs["oliveira"] = {
    .427,
    .606,
    .720,
    .805,
    .710,
    .751,
    .903,
    .816,
    .838,
}

INC = IDAs[NAME]
DMC = 6           -- class dmc of (50 cm)
NEW_TREES = 16    -- tree/ha/ano
CUT_CICLE = 30    -- lapse between cut cicles
YPL = 10          -- years per loop
time = 90         -- years of simulation
DAMAGE_EXP = 82   -- damage during exploaration
DAMAGE_AFTER = 64 -- damage after exploration

cell = Cell{
    trees_cut   = 0,
    trees_reman = 0,
    trees_seeds = 0,
    all_trees = 0,
    init = function(self)
        self:update_dest()
    end,
    update_dest = function(self)
        local cut = self:trees_count(DMC, 9)
        local seeds = math.ceil(cut * 0.1)
        cut = cut - seeds
        local reman = self:trees_count(DMC-2, DMC-1)

        -- remaining trees should be at least 10% of cut trees
        if reman < seeds and cut > 0  then
            cut = cut - (seeds - reman)
            reman = seeds
        end
       self.trees_cut = cut
        self.trees_seeds = seeds
        self.trees_reman = reman
        self.all_trees = self:trees_count(1,9)
    end,
    trees_count = function(self, from, to)
        local trees = 0
        for i = from, to do
            trees = trees + self["class"..i.."_sum"]
        end
        return trees
    end,
    regen = function(self)
        for i = 8, 1, -1 do
            local growing = 0
            growing = self["class"..i.."_sum"] * 0.20 * YPL * INC[i] / 2
            growing = round(growing)
            if self["class"..i.."_sum"] == 1 then
                growing = 1
            end
            self["class"..(i+1).."_sum"] = self["class"..(i+1).."_sum"] + growing
            self["class"..i.."_sum"] = self["class"..i.."_sum"] - growing
        end
        -- Adding new trees
        self.class1_sum = self.class1_sum + NEW_TREES * YPL
    end,
    extract = function(self)
        local trees_total = self.trees_cut
        local trees = 0
        local c = 9
        -- extrating trees
        while trees < trees_total and c >= DMC do
            trees = trees + self["class"..c.."_sum"]
            if trees > trees_total then
                self["class"..c.."_sum"] = trees - trees_total
                trees = trees_total
            else
                self["class"..c.."_sum"] = 0
            end
            c = c - 1
        end
        self.trees_cut = 0
        -- damaging
        c = 1
        local dmg = 0
        local dmg_total = DAMAGE_AFTER + DAMAGE_EXP
        while dmg > dmg_total and c <= 9 do
            dmg = dmg + self["class"..c.."_sum"]
            if dmg > dmg_total then
                self["class"..c.."_sum"] = dmg_total - dmg
                dmg = dmg_total
            else
                self["class"..c.."_sum"]  = 0
            end
            c = c + 1
        end
    end
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
}

df = DataFrame{
    class1 = {cs:class1_sum()},
    class2 = {cs:class2_sum()},
    class3 = {cs:class3_sum()},
    class4 = {cs:class4_sum()},
    class5 = {cs:class5_sum()},
    class6 = {cs:class6_sum()},
    class7 = {cs:class7_sum()},
    class8 = {cs:class8_sum()},
    class9 = {cs:class9_sum()},
    trees_cut = {cs:trees_cut()},
    trees_reman = {cs:trees_reman()},
    trees_seeds = {cs:trees_seeds()}
}

cuts = DataFrame{
    cut= {cs:trees_cut()}
}

toDF = function()
    df:add{
        class1 = cs:class1_sum(),
        class2 = cs:class2_sum(),
        class3 = cs:class3_sum(),
        class4 = cs:class4_sum(),
        class5 = cs:class5_sum(),
        class6 = cs:class6_sum(),
        class7 = cs:class7_sum(),
        class8 = cs:class8_sum(),
        class9 = cs:class9_sum(),
        trees_cut = cs:trees_cut(),
        trees_reman = cs:trees_reman(),
        trees_seeds = cs:trees_seeds()
    }
end

t = Timer{
    Event{ action = function()
            local curr = t:getTime()
            cs:regen()
            cs:update_dest()
            if curr%(CUT_CICLE//YPL) == 0 then
                cuts:add{cut=cs:trees_cut()}
                --cs:extract()
            end
            toDF()
    end},
}

round = function(x)
    if x%1 >= 0.5 then
        return math.ceil(x)
    else
        return math.floor(x)
    end
end
print(cs:all_trees())
t:run(time//YPL)
print("Saving output...")
--df:save(NAME.."/"..NAME.."ex2.csv")
--cuts:save(NAME.."/cutsex2.csv")
--cs:save(NAME.."ex2", {"class1_sum","class2_sum","class3_sum","class4_sum","class5_sum","class6_sum","class7_sum","class8_sum","class9_sum", "trees_cut","trees_seeds", "trees_reman"})
print("Output saved")
print(cs:all_trees())