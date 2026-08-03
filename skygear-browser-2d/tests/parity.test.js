import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {ARTICLES,CARDS,CLASSES,ELEMENTS,FITTINGS,HEAT,SHAPES,TALENTS,WAVES,makeSkill} from '../src/parity-data.js';
import {RNG,applyCard,awardRun,freshMeta,newMods,resolvedTalents,rollCards,waveManifest} from '../src/parity-systems.js';

test('complete Godot-facing combat catalogue is present',()=>{
  assert.equal(Object.keys(SHAPES).length,9); assert.equal(Object.keys(ELEMENTS).length,4);
  assert.equal(Object.keys(CLASSES).length,2); assert.equal(CARDS.length,40);
  assert.equal(Object.keys(TALENTS).length,23); assert.equal(Object.keys(ARTICLES).length,9);
  assert.equal(Object.keys(FITTINGS).length,6); assert.equal(HEAT.length,6);
  const matrix=Object.keys(SHAPES).flatMap(shape=>Object.keys(ELEMENTS).map(element=>makeSkill(shape,element)));
  assert.equal(matrix.length,36); assert.equal(new Set(matrix.map(skill=>`${skill.shape}:${skill.element}`)).size,36);
});

test('twelve-wave manifest and set-piece events match progression',()=>{
  assert.equal(WAVES.length,12); assert.deepEqual([WAVES[3].event,WAVES[7].event,WAVES[11].event],['grapple','blackout','colossus']);
  const manifest=waveManifest(5); assert.match(manifest,/armored/); assert.match(manifest,/swarm/);
});

test('draft cards mutate the run and first losses remain in the log',()=>{
  const run={rng:new RNG('CARDS'),wave:1,heat:0,heatData:{draftOffers:4},cards:[],mods:newMods(),skills:[makeSkill('CLOSEHIT','EMBER')],talents:{},classId:'captain',articles:{},rerolls:2,telemetry:{per:[{casts:0,damage:0}],rangeTime:{}},player:{maxHp:100,hp:100,maxDashes:2,dashes:2},boiler:{maxHp:500,hp:500}};
  const offers=rollCards(run,3); assert.equal(offers.length,3); applyCard(run,offers[0]); assert.equal(run.cards.length,1);
  const meta=freshMeta(); const bank=awardRun(meta,{won:false,wave:1,seed:'LOSS',classId:'captain',heat:0,vents:0,closeShare:0,healed:0});
  assert.equal(bank.scrip,0); assert.equal(meta.runs.length,1); assert.equal(meta.unlocked,false); assert.deepEqual(resolvedTalents(meta),{});
});

test('browser entry point is the published V1 runtime with parity layer',async()=>{
  const html=await readFile(new URL('../index.html',import.meta.url),'utf8');
  const classic=await readFile(new URL('../index.html',import.meta.url),'utf8');
  const layer=await readFile(new URL('../src/v1-parity.js',import.meta.url),'utf8');
  assert.match(html,/<canvas id="c"><\/canvas>/); assert.match(html,/src\/v1-parity\.js/);
  assert.match(classic,/window\.SKYGEAR/); assert.match(classic,/nearestLiveEnemy/); assert.match(classic,/Slot 0 is the class basic attack/); assert.match(layer,/THE OPENING DRAFT/); assert.match(layer,/OPENING_SKILLS/); assert.match(layer,/v1-mobile-controls/); assert.match(layer,/AUTO-AIM/); assert.match(layer,/boilerwright/);
});
